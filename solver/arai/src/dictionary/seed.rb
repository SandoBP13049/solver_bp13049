# -*- coding: utf-8 -*-
require 'dictionary/katsuyo'
#$KCODE="u"
#coding:utf-8

#
# 辞書に登録する単語の種(語幹と活用形の組)
#
class RS::Dictionary::Seed

  public
  # @param [String] seed_file ファイル名
  def initialize(seed_file)
    @seed_file = seed_file
    @file = open(seed_file)
    @katsuyo = RS::Dictionary::Katsuyo.new
    @ln = 1
  end

  public
  # ファイルをクローズする。
  def done
    @file.close
    @file = nil
  end

  public
  # @return [Array<String>, nil] 次の語のリスト。次の語がなければnil。
  def next_words
    if @file == nil
      return nil
    end
    if line = @file.gets
      words = parse(line)
      @ln = @ln + 1
      return words
    else
      done
      return nil
    end
  end

  private
  # @param [String] seedファイルの一行
  # @return [Array<String>] 展開して得られた語のリスト
  def parse(line)
    if /^#/ =~ line
      # コメント行
      return []
    end
    line.chomp!
    cmds = line.split(/,/)

    if cmds.size == 0
      return []
    elsif cmds.size == 1
      # 活用語, 見出し=登録する語
      return [cmds[0]]
    end

    # 見出し語,...
    result = []
    cmds.shift # 先頭の見出し語は捨てる
    cmds.each {|c|
      if /(.*):(.+)/ =~ c
        # 活用語
        # 語幹の読み:活用の種類 or 語の読み:活用形
        yomi = $1
        modifier = $2
        # 現段階では活用形の情報は捨てて、読みだけを保存する。
        if /^(未然|連用|終止|連体|已然|命令)/ =~ modifier
          result += yomi.split(/-/)
        elsif /^(.+)行四段/ =~ modifier
          result += @katsuyo.yo_dan($1,yomi).map {|k,v| v}.flatten
        elsif /^ナ行変格/ =~ modifier
          result += @katsuyo.na_hen(yomi).map {|k,v| v}.flatten
        elsif /^ラ行変格/ =~ modifier
          result += @katsuyo.ra_hen(yomi).map {|k,v| v}.flatten
        elsif /^(.+)行下一段/ =~ modifier
          result += @katsuyo.shimo_ichi_dan($1,yomi).map {|k,v| v}.flatten
        elsif /^(.+)行下二段/ =~ modifier
          result += @katsuyo.shimo_ni_dan($1,yomi).map {|k,v| v}.flatten
        elsif /^(.+)行上一段/ =~ modifier
          result += @katsuyo.kami_ichi_dan($1,yomi).map {|k,v| v}.flatten
        elsif /^(.+)行上二段/ =~ modifier
          result += @katsuyo.kami_ni_dan($1,yomi).map {|k,v| v}.flatten
        elsif /^カ行変格/ =~ modifier
          result += @katsuyo.ka_hen(yomi).map {|k,v| v}.flatten
        elsif /^サ行変格/ =~ modifier
          result += @katsuyo.sa_hen(yomi).map {|k,v| v}.flatten
        elsif /^シク/ =~ modifier
          result += @katsuyo.shiku(yomi).map {|k,v| v}.flatten
        elsif /^ク/ =~ modifier
          result += @katsuyo.ku(yomi).map {|k,v| v}.flatten
        elsif /^ナリ/ =~ modifier
          result += @katsuyo.nari(yomi).map {|k,v| v}.flatten
        elsif /^タリ/ =~ modifier
          result += @katsuyo.tari(yomi).map {|k,v| v}.flatten
        else
          raise UndefinedKatsuyoException, "#{@seed_file}:#{@ln}:Error '#{line.chomp}'"
        end
      else
        # 非活用語
        result.push(c) if c.length > 0
      end
    }
    return result
  end

end
