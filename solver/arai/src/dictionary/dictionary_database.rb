# -*- coding: utf-8 -*-
require 'set'
require 'rubygems'
require 'sqlite3'
require 'csp/reading_assignment'
#$KCODE="u"
#coding:utf-8

module RS::Dictionary
  #
  # 辞書クラスの基底クラス
  #
  # @example データベースのスキーマ
  #  CREATE TABLE word (  # 単語テーブル
  #  id  INTEGER PRIMARY KEY,
  #  text TEXT UNIQUE,    # 単語
  #  length INTEGER       # 単語長
  #  );
  #  CREATE TABLE IF NOT EXISTS occurrence (  # 文字の出現テーブル
  #  id INTEGER,          # 単語のid
  #  position INTEGER,    # 単語内の位置(0, 1, 2, ..., length-1)
  #  char TEXT,           # 文字
  #  length INTEGER,      # 単語長
  #  FOREIGN KEY (id) REFERENCES word(id)
  #  );
  #  CREATE INDEX wordId ON word (id);
  #  CREATE INDEX wordLength ON word (length);
  #  CREATE INDEX occurrencePositionCharLength ON occurrence (position,char,length);
  class DictionaryBase
    # テーブル作成のためのSQL文
    SQL_STATEMENTS_FOR_TABLE_CREATION = <<-SQL
DROP TABLE IF EXISTS word;
DROP TABLE IF EXISTS occurrence;
CREATE TABLE word (
  id  INTEGER PRIMARY KEY,
  text TEXT UNIQUE,
  length INTEGER
);
CREATE TABLE IF NOT EXISTS occurrence (
  id INTEGER,
  position INTEGER,
  char TEXT,
  length INTEGER,
  FOREIGN KEY (id) REFERENCES word(id)
);
CREATE INDEX wordId ON word (id);
CREATE INDEX wordLength ON word (length);
CREATE INDEX occurrencePositionCharLength ON occurrence (position,char,length);
SQL

    public
    # コンストラクタ
    # @param [SQLite3::Database] db SQLiteデータベースへの接続
    def initialize(db)
      @db = db
    end

    public
    # データベースを閉じる。
    def done
      @db.close
    end

    public
    # domain内のいずれかの文字を含む単語の最大長
    #
    # @param [Array<String>] domain 文字の配列
    # @return [Integer] 最大長
    def max_word_length(domain)
      sql = "SELECT MAX(length) FROM word WHERE id IN (SELECT id FROM OCCURRENCE WHERE " + (domain.map {|w| "char=\"" + w.to_s + "\""}).join(' OR ') + ")"
      result_set = @db.execute(sql)
      if result_set[0][0] == nil
        return 0
      end
      max_length = result_set[0][0].to_i
      return max_length
    end

    public
    # 変数列, 単語, 読み開始位置の対応の集合
    #
    # @param [CSP::ConstraintSatisfactionProblem] csp 制約充足問題
    # @param [Array<Symbol>] var_path 変数列
    # @param [Integer] word_length 単語長
    # @param [Integer] start_position 変数列の先頭の単語内の位置(単語の先頭が0)。先頭変数を単語の指定位置に合わせて単語を探索する。
    # @return [Set<RS::CSP::ReadingAssignment>]
    # @example 戻り値の要素の例。変数列:x1, :x2を、単語"あいう"の開始位置1から重ねる。変数:x1に"い", 変数:x2に"う"が対応する。
    #  RS::CSP::ReadingAssignment.new([:x1, :x2], ["あ", "い", "う"], 1)
    # @todo 例外処理
    def retrieve_words(csp, var_path, word_length, start_position)
      # select文を組み立てる。
      selects = []
      sub_start_position = start_position
      var_path.each do |v|
        if !csp.domains[v].include?(RS::ANY_CHAR)
          subsql = "word.id IN (SELECT id FROM occurrence WHERE position=#{sub_start_position} AND length = #{word_length} AND ("
          subsql += (csp.domains[v].map {|d| "char=\"#{d}\""}).to_a.join(' OR ')
          subsql += "))"
          selects.push(subsql)
        end
        sub_start_position += 1
      end
      if selects.size > 0
        sql = "SELECT text FROM word WHERE " + selects.join(" AND ").to_s + ";"
      else
        sql = "SELECT text FROM word;"
      end

      # select文を実行する。
      begin
        rows = @db.execute(sql)
      rescue
        puts sql
        exit # この処理は適切か?
      end

      # 問い合わせ結果を回収する。
      result = Set.new
      rows.each {|row|
        result.add(RS::CSP::ReadingAssignment.new(var_path, row[0], start_position))
      }
      return result
    end

    public
    # 変数列に重ねられる単語の集合
    #
    # @param [CSP::ConstraintSatisfactionProblem] csp 制約充足問題
    # @param [Array<Symbol>] var_path 変数列
    # @param [Integer] word_length 単語長
    # @return [Set<RS::CSP::ReadingAssignment>]
    # @see #retrieve_words
    def words_matched_with(csp, var_path, word_length)
      if var_path.length > word_length
        return Set.new
      end

      if var_path.length == word_length
        return retrieve_words(csp, var_path, word_length, 0)
      end

      # var_path.length < word_length
      if csp.heads.include?(var_path[0]) && csp.tails.include?(var_path[var_path.size-1])
        # 両端とも端
        # 変数列の末尾と単語の右端とを合わせる.-> 変数列の先頭と単語の左端とを合わせる.
        result = Set.new
        (word_length - var_path.length).downto(0) do |i|
          result = result + retrieve_words(csp, var_path, word_length, i)
        end
        return result
      elsif csp.heads.include?(var_path[0])
        # 変数列の末尾と単語の右端とを合わせる.
        return retrieve_words(csp, var_path, word_length, word_length - var_path.length)
      elsif csp.tails.include?(var_path[var_path.size-1])
        # 変数列の先頭と単語の左端とを合わせる.
        return retrieve_words(csp, var_path, word_length, 0)
      else
        return Set.new
      end
    end
  end

  #
  # 辞書データベースをファイルとして持つ辞書
  #
  class FileDictionary < DictionaryBase

    public
    # @param [String] db_file データベースファイル名
    def initialize(db_file)
      db = SQLite3::Database.new(db_file)
      super(db)
    end
  end

  #
  # 単語登録機能を持つ、空の辞書。
  #
  class EmptyFileDictionary < DictionaryBase

    public
    # @param [String] db_file データベースファイル名
    def initialize(db_file)
      db = SQLite3::Database.new(db_file)
      db.execute_batch(SQL_STATEMENTS_FOR_TABLE_CREATION)
      @word_id = 0
      super(db)
    end

    private
    # 単語登録に用いるidを生成する。
    # @return [Integer] 次のid
    def next_word_id
      @word_id = @word_id + 1
      return @word_id
    end

    public
    # 辞書へ単語を登録する。
    #
    # @param [String] word 登録する単語
    def insert_word(word)
      id = next_word_id()
      begin
        # 単語の登録
        sql = "INSERT INTO word (id,text,length) VALUES("+id.to_s+",'" + word + "'," + word.split(//).length.to_s + ")"
        @db.execute_batch(sql) # 同じ単語を登録する場合は例外発生. rescueへ.

        # 文字の出現の登録
        pos = 0
        length = word.split(//).length
        word.split(//).each do |ch|
          sql = "INSERT INTO occurrence (id,position,char,length) VALUES("+id.to_s+","+pos.to_s+",'"+ch+"',"+length.to_s+")"
          @db.execute_batch(sql)
          pos += 1
        end
      rescue
        # 例外が発生しても何もしない
        rescued = true
      end
    end

  end

  #
  # 辞書データベースをメモリに持つ辞書
  #
  class MemDictionary < DictionaryBase

    public
    # 指定された辞書データベースをメモリにコピーして保持する。
    #
    # @param [String] db_file メモリに格納すべき辞書データベースのファイル名
    def initialize(db_file)
      src_db = SQLite3::Database.new(db_file)     # コピー元
      dst_db = SQLite3::Database.new(':memory:') # コピー先
      dst_db.execute_batch(SQL_STATEMENTS_FOR_TABLE_CREATION)

      # コピー
      insert_into_word = "INSERT INTO word (id,text,length) VALUES(?, ?, ?)"
      insert_into_occurrence = "INSERT INTO occurrence (id,position,char,length) VALUES(?, ?, ?, ?)"
      dst_db.transaction do
        src_db.execute('select * from word') do |row|
          dst_db.execute(insert_into_word, row[0], row[1], row[2])
        end
        src_db.execute('select * from occurrence') do |row|
          dst_db.execute(insert_into_occurrence, row[0], row[1], row[2], row[3])
        end
      end
      src_db.close

      super(dst_db)
    end
  end

end # end of the module Dictionary
