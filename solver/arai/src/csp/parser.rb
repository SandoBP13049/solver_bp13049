#!/usr/bin/ruby
# -*- coding: utf-8 -*-
require 'set'
#require 'jcode'
#$KCODE="u"
#coding:utf-8

#
# テキスト表現された制約充足問題の字句解析器、構文解析器のモジュール
#
module RS::CSP::Text
end

#
# @abstract ビジターパターンのビジタークラス。サブクラスで{#visit}を実装する。
# @see RS::CSP::Text::Acceptor
#
class RS::CSP::Text::Visitor
  public
  # 引数のオブジェクトのacceptメソッドを呼ぶようにサブクラスで実装する。
  # @param [#accept] obj 訪問する対象
  def visit(obj)
  end
end

#
# VisitorパターンのAcceptorクラス
# @see RS::CSP::Text::Visitor
#
class RS::CSP::Text::Acceptor
  public
  # 引数のvisitメソッドを呼ぶ。
  # @param [#visit] obj
  def accept(obj)
    obj.visit(self)
  end
end

#
# 変数を収集するビジタークラス
#
class RS::CSP::Text::VarCollector < RS::CSP::Text::Visitor
  # @return [Array<Symbol>] 変数の列
  attr_reader :vars

  public
  # コンストラクタ
  def initialize
    @vars = {}
  end

  public
  # 領域式に含まれる変数の列をインスタンス変数@varsに記録する。
  # @param [RS::CSP::Text::DomainExpression] dexp 領域式
  # @todo エラー処理
  def visit(dexp)
    if RS::CSP::Text::VarExpression === dexp
      @vars[dexp.name] = dexp.domain
    elsif RS::CSP::Text::SequenceExpression === dexp
      dexp.sequence.each do |subdexp|
        subdexp.accept(self)
      end
    elsif RS::CSP::Text::SelectExpression === dexp
      dexp.select.each do |subdexp|
        subdexp.accept(self)
      end
    elsif RS::CSP::Text::CSPExpression === dexp
      dexp.vars.each do |subdexp|
        subdexp.accept(self)
      end
    else
      puts "error"
    end
  end
end

#
# 変数の結合性を収集するビジタークラス
#
class RS::CSP::Text::ConnectivityCollector < RS::CSP::Text::Visitor
  # @return [Array<Symbol>] 変数の列
  attr_reader :connectivity

  public
  # コンストラクタ
  def initialize
    @connectivity = []
  end

  public
  # 領域式で指定される変数の結合性をインスタンス変数@connectivityに記録する。
  # @param [RS::CSP::Text::DomainExpression] dexp 領域式
  # @todo エラー処理
  def visit(dexp)
    if RS::CSP::Text::VarExpression === dexp
    elsif RS::CSP::Text::SequenceExpression === dexp
      if dexp.sequence.size == 1
        dexp.sequence[0].accept(self)
      elsif dexp.sequence.size > 1
        t = dexp.sequence[0].tails
        i = 1
        while(i < dexp.sequence.size)
          h = dexp.sequence[i].heads
          t.each do |vs|
            h.each do |ve|
              @connectivity.push([vs.name, ve.name])
            end
          end
          t = dexp.sequence[i].tails
          i += 1
        end
        dexp.sequence.each do |subdexp|
          subdexp.accept(self)
        end
      end
    elsif RS::CSP::Text::SelectExpression === dexp
      dexp.select.each do |subdexp|
        subdexp.accept(self)
      end
    elsif RS::CSP::Text::CSPExpression === dexp
      dexp.vars.each do |subdexp|
        subdexp.accept(self)
      end
    else
      puts "error"
    end
  end
end

#
# 制約を収集するビジタークラス
#
class RS::CSP::Text::ConstraintCollector < RS::CSP::Text::Visitor
  # @return [Array<RS::CSP::Text::ConstraintExpression>] 制約の列
  attr_reader :constraints

  public
  # コンストラクタ
  def initialize
    @constraints = []
  end

  public
  # 領域式で指定される制約をインスタンス変数@consに記録する。
  # @param [RS::CSP::Text::DomainExpression] dexp 領域式
  # @todo エラー処理
  def visit(dexp)
    if RS::CSP::Text::CSPExpression === dexp
      dexp.cons.each do |c|
        @constraints.push(c)
      end
    else
      puts "error"
    end
  end
end

#
# 領域式(変数とその領域との組, そして変数の結合性を表す式)のオブジェクト。
# 構文解析によって構築されるモデル。
#
class RS::CSP::Text::DomainExpression < RS::CSP::Text::Acceptor

  public
  # 先頭の変数の集合
  # @return [Set] 空集合
  def heads
    return Set.new
  end

  public
  # 末尾の変数の集合
  # @return [Set] 空集合
  def tails
    return Set.new
  end

  public
  # 制約充足問題のハッシュ表現の文字列を返す。
  # @return [String] 制約充足問題のハッシュ表現の文字列
  def to_csp_hash_as_string
    vc = RS::CSP::Text::VarCollector.new
    self.accept(vc)
    vars = vc.vars

    connectivity_collector = RS::CSP::Text::ConnectivityCollector.new
    self.accept(connectivity_collector)
    connectivity = connectivity_collector.connectivity

    constraint_collector = RS::CSP::Text::ConstraintCollector.new
    self.accept(constraint_collector)
    constraints = constraint_collector.constraints

    result = "{\n"
    result += " :vars=>"
    result += "{" + (vars.map { |k,v| ":#{k}=>[" + (v.map {|kana| "'#{kana}'"}).to_a.join(', ') + "]"}).to_a.join(', ') + "},\n"
    result += " :connectivity=>"
    result += "["
    result += (connectivity.map {|x| "[:#{x[0]}, :#{x[1]}]"}).to_a.join(', ')
    result += "],\n"
    result += " :constraints=>[\n"

    maxStrength = (constraints.map {|c| c.strength}).max
    sub_result = []
    0.upto(maxStrength).each {|s|
      sub_result.push("  [ " + (constraints.select {|c| c.strength == s}).map {|c| c.to_s}.to_a.join(', ') + " ]")
    }
    result += sub_result.join(", \n") + "\n"
    result += "               ]\n"
    result += "}"
    return result
  end

  public
  # 制約充足問題を返す。
  # @return [Hash] 制約充足問題のハッシュ表現
  def to_csp_hash
    return eval(to_csp_hash_as_string)
  end
end

#
# 変数名と領域の組を表す式。構文解析によって構築されるモデル。
# @example 対応する生成規則
#  ImpVarDef := kana | '{' kana (',' kana)* '}' |  '(' VarDefSel ')'
#  ExpVarDef := id ('in' '{' kana (',' kana)* '}' | '=' kana)
#
class RS::CSP::Text::VarExpression < RS::CSP::Text::DomainExpression
  # @return [Symbol] 変数名
  attr_reader :name
  # @return [Set<String>] 変数の領域
  attr_reader :domain

  public
  # コンストラクタ
  def initialize(name, domain)
    super()
    @name = name
    @domain = domain
  end

  public
  # 先頭の変数の集合
  # @return [Set<RS::CSP::Text::VarExpression>] この変数だけからなる集合
  def heads
    return Set.new [self]
  end

  public
  # 末尾の変数の集合
  # @return [Set<RS::CSP::Text::VarExpression>] この変数だけからなる集合
  def tails
    return Set.new [self]
  end

  public
  # 文字列化メソッド
  # @return [String] 変数名の文字列
  def to_s
    return ":#{@name.to_s}"
    #    return "#{@name.to_s} in {#{(@domain.map {|x| x.to_s}).join(',')}}"
  end
end

#
# 領域式の列を表す式。構文解析によって構築されるモデル。
# @example 対応する生成規則
#  VarDefSeq := (ImpVarDef+ | ExpVarDef ) (',' (ImpVarDef+ | ExpVarDef))*
#
class RS::CSP::Text::SequenceExpression < RS::CSP::Text::DomainExpression
  # @return [Array<RS::CSP::Text::DomainExpression>] 領域式の列
  attr_reader :sequence

  public
  # コンストラクタ
  def initialize()
    super()
    @sequence = []
  end

  public
  # 先頭の変数の集合
  # @return [Set<RS::CSP::Text::VarExpression>] 先頭の変数の集合
  def heads
    if @sequence.size > 0
      return @sequence[0].heads
    end
    return Set.new
  end

  public
  # 末尾の変数の集合
  # @return [Set<RS::CSP::Text::VarExpression>] 末尾の変数の集合
  def tails
    if @sequence.size > 0
      return @sequence[@sequence.size-1].tails
    end
    return Set.new
  end

  public
  # 列に領域式を加える。
  # @param [RS::CSP::Text::DomainExpression] exp 列に加える領域式
  def add(exp)
    @sequence.push(exp)
  end

  public
  # 文字列化メソッド
  # @return [String] この領域式の列を表す文字列
  def to_s
    (@sequence.map {|x| x.to_s}).join(', ')
  end
end

#
# 選択を表す領域式。構文解析によって構築されるモデル。
# @example 対応する生成規則
#  VarDefSel := VarDefSeq ('|' VarDefSeq)*
#
class RS::CSP::Text::SelectExpression < RS::CSP::Text::DomainExpression
  # @return [Array<RS::CSP::Text::DomainExpression>] 領域式の列
  attr_reader :select

  public
  # コンストラクタ
  def initialize()
    super()
    @select = []
  end

  public
  # 先頭の変数の集合
  # @return [Set<RS::CSP::Text::VarExpression>] 先頭の変数の集合
  def heads
    result = Set.new
    @select.each do |dexp|
      dexp.heads.each do |h|
        result.add(h)
      end
    end
    return result
  end

  public
  # 末尾の変数の集合
  # @return [Set<RS::CSP::Text::VarExpression>] 末尾の変数の集合
  def tails
    result = Set.new
    @select.each do |dexp|
      dexp.tails.each do |t|
        result.add(t)
      end
    end
    return result
  end

  public
  # 選択に領域式を加える。
  # @param [RS::CSP::Text::DomainExpression] exp 選択に加える領域式
  def add(exp)
    @select.push(exp)
  end

  public
  # 文字列化メソッド
  # @return [String] この領域式の列を表す文字列
  def to_s
    "(" + (@select.map {|x| x.to_s }).join('|') + ")"
  end
end

#
# 制約を表す領域式。構文解析によって構築されるモデル。
# @example 対応する生成規則
#  ConDefStmt := 'constraint' Term ('==' | '!=') Term ';'
#  2012/10/25 上記式を下記に変更
#  ConDefStmt := 'constraint' ( Term ('==' | '!=') Term | ('bow' | 'eow') '(' Term ')') ';'
#
#  Term := id | 'U' '(' id ',' integer ')' # 後半の 'U' '(' id ',' integer ')' だけに対応
#
class RS::CSP::Text::ConstraintExpression < RS::CSP::Text::DomainExpression
  # @return [Symbol] 制約名
  attr_reader :name
  # @return [Array<String>] 制約の引数
  attr_reader :vars
  # @return [Integer] 制約の優先度 0, 1, 2, ...
  attr_reader :strength

  public
  # コンストラクタ
  # 2012/11/05 複数変数に対応. 新井
  # @param [Symbol] name 制約名
  # @param [Array<Array<Symbol, String>>] vars 引数
  # @param [Integer] strength 制約の優先度 0, 1, 2, ...
  def initialize(name, vars, strength=0)
    super()
    @name = name
    @vars = vars
    @strength = strength
  end

  public
  # 文字列化メソッド
  # @return [String] この制約を表す文字列
  def to_s
    str = "[:#{@name.to_s}"
    @vars.each{|v|
      str << ", #{v.to_s}"
    }
    str << "]"
  end
end

# @abstract 制約の引数(識別子, 関数)を表す項の抽象クラス。
# @see RS::CSP::Text::ConstraintExpression
class RS::CSP::Text::Term
end

#
# 識別子を表す項
#
class RS::CSP::Text::IdTerm < RS::CSP::Text::Term
  # @return [String] 識別子
  attr_reader :name

  public
  # コンストラクタ
  # @param [String] name 識別子
  def initialize(name)
    @name = name
  end

  public
  # 文字列化メソッド
  # @return [String] 識別子を表す文字列
  def to_s
    return ":#{@name.to_s}"
  end
end

#
# 関数を表す項
#
class RS::CSP::Text::FunctionTerm < RS::CSP::Text::Term
  # @return [String] 関数名
  attr_reader :name
  # @return [Array<#to_s>] 引数の列
  attr_reader :vars

  public
  # コンストラクタ
  # @param [Symbol] name 関数名
  # @param [#to_s] v1 第一引数
  # @param [#to_s] v2 第二引数
  def initialize(name, v1, v2)
    super()
    @name = name
    @vars = [v1, v2]
  end

  public
  # 文字列化メソッド
  # @return [String] 関数を表す文字列
  def to_s
    return "[:#{@name}, #{@vars[0].to_s}, #{@vars[1].to_s}]"
  end
end

#
# 制約充足問題の記述。構文解析によって構築されるモデル。
# 領域式は制約充足問題の構想要素であるが、便宜上、DomainExpression(領域式)のサブクラスとしている。
# @example 対応する生成規則
#  CSP := VarDefStmt+ ConDefStmt*
#
class RS::CSP::Text::CSPExpression < RS::CSP::Text::DomainExpression
  # @return [Array<RS::CSP::Text::DomainExpression>] 変数定義
  attr_reader :vars
  # @return [Array<RS::CSP::Text::ConstraintExpression>] 制約定義
  attr_reader :cons

  public
  # コンストラクタ
  def initialize()
    super()
    @vars = []
    @cons = []
  end

  public
  # 先頭の変数の集合
  # @return [Set<RS::CSP::Text::VarExpression>] 先頭の変数の集合
  def heads
    result = Set.new
    @vars.each do |dexp|
      dexp.heads.each do |h|
        result.add(h)
      end
    end
    return result
  end

  public
  # 末尾の変数の集合
  # @return [Set<RS::CSP::Text::VarExpression>] 末尾の変数の集合
  def tails
    result = Set.new
    @vars.each do |dexp|
      dexp.tails.each do |t|
        result.add(t)
      end
    end
    return result
  end

  public
  # 変数定義を追加する。
  # @param vars [RS::CSP::Text::DomainExpression] 領域式
  def add_vars(vars)
    @vars.push(vars)
  end

  public
  # 制約を追加する。
  # @param con [RS::CSP::Text::ConstraintExpression] 制約式
  def add_constraint(con)
    @cons.push(con)
  end

  public
  # 文字列化メソッド
  # @return [String] 制約充足問題の内容を表す文字列
  def to_s
    return "var\n" + @vars.map {|x| x.to_s}.join("\n") + "\nconstraint\n" + @cons.map {|x| x.to_s}.join("\n")
  end
end

#
# 字句
#
# @see RS::CSP::Text::Lexer
#
class RS::CSP::Text::Token
  # @return [Symbol] 字句の種類
  attr_reader :kind
  # @return [String] 字句の値
  attr_reader :value

  public
  # コンストラクタ
  # @param [Symbol] kind 字句の種類
  # @param [String] value 字句の値
  def initialize(kind, value)
    @kind = kind
    @value = value
  end

  public
  # 文字列化メソッド
  # @return [String] 字句を表す文字列
  def to_s
    return "(#{@kind}, '#{@value}')"
  end
end

#
# 字句解析器
#
class RS::CSP::Text::Lexer
  # @return [Integer] 注目する文字のテキスト全体内での位置
  attr_reader :cursor
  # @return [Integer] 注目する文字の行番号
  attr_reader :line
  # @return [Integer] 注目する文字の行内の位置
  attr_reader :char

  # 字句のパターンと種類
  TOKEN_DEF = [
               {:pattern=>/^(\()/, :token=>:LPAREN},
               {:pattern=>/^(\))/, :token=>:RPAREN},
               {:pattern=>/^(\{)/, :token=>:LBRACE},
               {:pattern=>/^(\})/, :token=>:RBRACE},
               {:pattern=>/^(\|)/, :token=>:VERT},
               {:pattern=>/^(,)/, :token=>:COMMA},
               {:pattern=>/^(\;)/, :token=>:SEMICOLON},
               {:pattern=>/^(==)/, :token=>:EQ_CON},
               {:pattern=>/^(!=)/, :token=>:NE_CON},
               {:pattern=>/^(=)/, :token=>:EQUAL},
               {:pattern=>/^(in)/, :token=>:IN},
               {:pattern=>/^(var)/, :token=>:VAR},
               {:pattern=>/^(constraint)/, :token=>:CONSTRAINT},
               {:pattern=>/^(U)/, :token=>:U_FUNCTION},
               {:pattern=>/^(bow)/, :token=>:BW_FUNCTION}, # 2012/10/25 追加 Start of Word . 新井
               {:pattern=>/^(eow)/, :token=>:EW_FUNCTION}, # 2012/10/25 追加 End of Word . 新井
               {:pattern=>/^([1-9][0-9]*)/, :token=>:INTEGER},
               {:pattern=>/^([a-zA-Z][0-9a-zA-Z]*)/, :token=>:ID}
              ]

  public
  # コンストラクタ
  # @param [String] text 解析対象のテキスト
  def initialize(text)
    @contents = text.split(//)
    @cursor = 0
    @line = 1
    @char = 1
  end

  public
  # 次の字句
  # @return [RS::CSP::Text::Token] 次の字句
  def next_token()
    nt = _next_token()
    # 誤りへの対応になる?
    #    while(nt.kind == :UNKNOWN)
    #      nt = _next_token()
    #    end
    return nt
  end

  private
  # 次の字句。{#next_token}から呼ばれる。
  # @return [RS::CSP::Text::Token] 次の字句
  def _next_token()
    while(@cursor < @contents.length && @contents[@cursor] =~ /\s|\t|\r|\n/u) do
      if @contents[@cursor] =~ /\n/u
        @line += 1
        @char = 1
      else
        @char += 1
      end
      @cursor += 1
    end
    if (@cursor >= @contents.length)
      return RS::CSP::Text::Token.new(:EOT, "EOT")
    end
    TOKEN_DEF.each {|h|
      if h[:pattern] =~ @contents[@cursor, @contents.size].join('').gsub("\n", " ")
        letter = $1
        @cursor += letter.length
        @char += letter.length
        return RS::CSP::Text::Token.new(h[:token], letter)
      end
    }

    if (@contents[@cursor] =~ /[ぁ-ん]/u || @contents[@cursor] == RS::ODORIJI_1 || @contents[@cursor] == RS::ODORIJI_2 || @contents[@cursor] == RS::UNREADABLE_CHAR || @contents[@cursor] == RS::NOT_KANA) # ひらがな, ゝ, 々, !, or ?
      letter = @contents[@cursor]
      @cursor += 1
      @char += 1
      return RS::CSP::Text::Token.new(:LETTER, letter)
    end
    letter = @contents[@cursor]
    @cursor += 1
    @char += 1
    return RS::CSP::Text::Token.new(:UNKNOWN, letter)
  end
end

#
# 制約充足問題の構文解析器
#
# @example 制約充足問題の文法
#  CSP := VarDefStmt+ ConDefStmt*
#  # 変数定義
#  VarDefStmt := 'var' VarDefSel ';'
#  VarDefSel := VarDefSeq ('|' VarDefSeq)*
#  VarDefSeq := (ImpVarDef+ | ExpVarDef ) (',' (ImpVarDef+ | ExpVarDef))*
#  ImpVarDef := kana | '{' kana (',' kana)* '}' |  '(' VarDefSel ')'
#  ExpVarDef := id ('in' '{' kana (',' kana)* '}' | '=' kana)
#  # 制約定義
#  ConDefStmt := 'constraint' (Term ('==' | '!=') Term | ('bow'|'eow') '(' Term ')' ) ';' # 2012/10/29 変更 新井
#  Term := id | 'U' '(' id ',' integer ')'
#
class RS::CSP::Text::Parser

  public
  # コンストラクタ
  # @param [RS::CSP::Text::Lexer] lexer 字句解析器
  def initialize(lexer)
    @lexer = lexer
    @errors = 0
    @warnings = 0
    @next_token = lexer.next_token
    @variable = 0
  end

  private
  # 新しい変数名
  # @return [String] 新しい変数名
  def next_var_name
    @variable += 1
    num = sprintf("%2.2d", @variable)
    return "_#{num}"
  end

  private
  # エラーを出力する。エラーがあったことを記録する。
  # @param [String] message エラーメッセージ
  def error(message)
    puts "error: #{message}"
    @errors += 1
  end

  private
  # 警告を出力する。警告があったことを記録する。
  # @param [String] message 警告メッセージ
  def warn(message)
    puts "warning: #{message}"
    @warnings += 1
  end

  public
  # 再帰降下構文解析をする。
  # @return [RS::CSP::Text::CSPExpression] 制約記述
  # @example 対応する生成規則
  #  CSP := VarDefStmt+ ConDefStmt*
  def parse()
    csp_description = RS::CSP::Text::CSPExpression.new
    if @next_token.kind == :VAR
      d = parse_VarDefStmt()
      csp_description.add_vars(d)
    else
      error("#{@lexer.line}:#{@lexer.char}: Unexpected token '#{@next_token.value}' A")
    end
    while @next_token.kind == :VAR
      d = parse_VarDefStmt()
      csp_description.add_vars(d)
    end

    while @next_token.kind == :CONSTRAINT
      c = parse_ConDefStmt()
      csp_description.add_constraint(c)
    end

    vc = RS::CSP::Text::VarCollector.new
    csp_description.accept(vc)
    vars = vc.vars

    vars.each {|v,d|
      csp_description.add_constraint(RS::CSP::Text::ConstraintExpression.new(:ne, [":#{v}", "\"#{RS::UNREADABLE_CHAR}\""] ,  1))
    }

    if @next_token.kind != :EOT
      error("#{@lexer.line}:#{@lexer.char}: Unexpected token '#{@next_token.value}' B")
    end

    return csp_description
  end

  private
  # 変数定義を構文解析する。
  # @return [RS::CSP::Text::SelectExpression] 変数定義(選択)
  # @example 対応する生成規則
  #  VarDefStmt := 'var' VarDefSel ';'
  def parse_VarDefStmt()
    if @next_token.kind == :VAR
      @next_token = @lexer.next_token()
    else
      error("#{@lexer.line}:#{@lexer.char}: 'var' is inserted. C")
    end
    exp = parse_VarDefSel()
    if @next_token.kind == :SEMICOLON
      @next_token = @lexer.next_token()
    else
      error("#{@lexer.line}:#{@lexer.char}: ';' is inserted. V")
    end
    return exp
  end

  private
  # 変数定義(選択)を構文解析する。
  # @return [RS::CSP::Text::SelectExpression] 変数定義(選択)
  # @example 対応する生成規則
  #  VarDefSel := VarDefSeq ('|' VarDefSeq)*
  def parse_VarDefSel()
    domain_sequences = []
    seq = parse_VarDefSeq()
    domain_sequences.push(seq)
    while @next_token.kind == :VERT
      @next_token = @lexer.next_token()
      seq = parse_VarDefSeq()
      domain_sequences.push(seq)
    end

    if domain_sequences.size == 1
      return domain_sequences[0]
    end
    result = RS::CSP::Text::SelectExpression.new
    domain_sequences.each do |ds|
      result.add(ds)
    end
    return result
  end

  private
  # 変数定義(列)を構文解析する。parse_VarDefSeqの下請け。
  # @return [Array<RS::CSP::Text::DomainExpression>] 領域式
  # @example 対応する生成規則
  #  VarDefSeq := (ImpVarDef+ | ExpVarDef) (',' (ImpVarDef+ | ExpVarDef))*  # この規則の (ImpVarDef+ | ExpVarDef) に対応する。
  # @see RS::CSP::Text::Parser#parse_VarDefSeq
  def parse_VarDefSeqSub()
    dexp_seq = []
    if @next_token.kind == :LETTER || @next_token.kind == :LBRACE || @next_token.kind == :LPAREN
      exp = parse_ImpVarDef()
      dexp_seq.push(exp)
      while @next_token.kind == :LETTER || @next_token.kind == :LBRACE || @next_token.kind == :LPAREN
        exp = parse_ImpVarDef()
        dexp_seq.push(exp)
      end
    elsif @next_token.kind == :ID
      exp = parse_ExpVarDef()
      dexp_seq.push(exp)
    else
      error("#{@lexer.line}:#{@lexer.char}: Unexpected token '#{@next_token.value}' F")
    end
    return dexp_seq
  end

  private
  # 変数定義(列)を構文解析する。
  # @return [RS::CSP::Text::SequenceExpression] 変数定義(列)
  # @example 対応する生成規則
  #  VarDefSeq := (ImpVarDef+ | ExpVarDef ) (',' (ImpVarDef+ | ExpVarDef))*
  def parse_VarDefSeq()
    dexp_seq = parse_VarDefSeqSub()
    while @next_token.kind == :COMMA
      @next_token = @lexer.next_token()
      subSeq = parse_VarDefSeqSub()
      dexp_seq.concat(subSeq)
    end
    if dexp_seq.size == 1
      return dexp_seq[0]
    end
    result = RS::CSP::Text::SequenceExpression.new
    dexp_seq.each do |d|
      result.add(d)
    end
    return result
  end

  private
  # 暗黙の変数定義(変数名を指定しない変数定義, implicit variable definition)を構文解析する。
  # @return [RS::CSP::Text::VarExpression, RS::CSP::Text::SelectExpression] 暗黙の変数定義もしくは変数定義列の選択
  # @example 対応する生成規則
  #  ImpVarDef := kana | '{' kana (',' kana)* '}' |  '(' VarDefSel ')'
  def parse_ImpVarDef()
    if @next_token.kind == :LETTER
      vname = next_var_name
      domain = Set.new [@next_token.value]
      var = RS::CSP::Text::VarExpression.new(vname, domain)
      @next_token = @lexer.next_token()
      return var
    elsif @next_token.kind == :LBRACE
      @next_token = @lexer.next_token()
      domain = Set.new
      if @next_token.kind == :LETTER
        domain.add(@next_token.value)
        @next_token = @lexer.next_token()
      else
        error("#{@lexer.line}:#{@lexer.char}: Unexpected token '#{@next_token.value}' G")
      end
      while @next_token.kind == :COMMA
        @next_token = @lexer.next_token()
        if @next_token.kind == :LETTER
          domain.add(@next_token.value)
          @next_token = @lexer.next_token()
        else
          error("#{@lexer.line}:#{@lexer.char}: Unexpected token '#{@next_token.value}' H")
        end
      end
      if @next_token.kind == :RBRACE
        @next_token = @lexer.next_token()
      else
        error("#{@lexer.line}:#{@lexer.char}: '}' is inserted. I")
      end
      vname = next_var_name
      return RS::CSP::Text::VarExpression.new(vname, domain)
    elsif @next_token.kind == :LPAREN
      @next_token = @lexer.next_token()
      exp = parse_VarDefSel()
      if @next_token.kind == :RPAREN
        @next_token = @lexer.next_token()
      else
        error("#{@lexer.line}:#{@lexer.char}: ')' is inserted. E")
      end
      return exp
    else
      error("#{@lexer.line}:#{@lexer.char}: Unexpected token '#{@next_token.value}' J")
    end
  end

  private
  # 明示的な変数定義(変数名を明示する変数定義, explicit variable definition)を構文解析する。
  # @return [RS::CSP::Text::VarExpression] 変数定義
  # @example 対応する生成規則
  #  ExpVarDef := id ('in' '{' kana (',' kana)* '}' | '=' kana)
  def parse_ExpVarDef()
    if @next_token.kind == :ID
      var_name = @next_token.value
      @next_token = @lexer.next_token()
    else
      var_name = "_"
      error("#{@lexer.line}:#{@lexer.char}: id is expected. K")
    end
    domain = Set.new

    if @next_token.kind == :IN
      @next_token = @lexer.next_token()
      if @next_token.kind == :LBRACE
        @next_token = @lexer.next_token()
        if @next_token.kind == :LETTER
          domain.add(@next_token.value)
          @next_token = @lexer.next_token()
        else
          error("#{@lexer.line}:#{@lexer.char}: Unexpected token '#{@next_token.value}' L")
        end
        while @next_token.kind == :COMMA
          @next_token = @lexer.next_token()
          if @next_token.kind == :LETTER
            domain.add(@next_token.value)
            @next_token = @lexer.next_token()
          else
            error("#{@lexer.line}:#{@lexer.char}: Unexpected token '#{@next_token.value}' M")
          end
        end
        if @next_token.kind == :RBRACE
          @next_token = @lexer.next_token()
        else
          error("#{@lexer.line}:#{@lexer.char}: '}' is inserted. N")
        end
      else
        error("#{@lexer.line}:#{@lexer.char}: Unexpected token '#{@next_token.value}' O")
      end
      return RS::CSP::Text::VarExpression.new(var_name, domain)
    elsif @next_token.kind == :EQUAL
      @next_token = @lexer.next_token()
      domain = Set.new
      if @next_token.kind == :LETTER
        domain.add(@next_token.value)
        @next_token = @lexer.next_token()
      else
        error("#{@lexer.line}:#{@lexer.char}: Unexpected token '#{@next_token.value}' P")
      end
      return RS::CSP::Text::VarExpression.new(var_name, domain)
    else
      error("#{@lexer.line}:#{@lexer.char}: Unexpected token '#{@next_token.value}' Q")
    end
    return RS::CSP::Text::VarExpression.new(var_name, domain)
  end

  private
  # 制約の項を構文解析する。
  # @return [RS::CSP::Text::IdTerm, RS::CSP::Text::FunctionTerm] 制約の項
  # @example 対応する生成規則
  #  Term := id | 'U' '(' id ',' integer ')'
  def parse_Term()
    if @next_token.kind == :ID
      id = @next_token.value
      @next_token = @lexer.next_token()
      return RS::CSP::Text::IdTerm.new(id)
    elsif @next_token.kind == :U_FUNCTION
      @next_token = @lexer.next_token()
      if @next_token.kind == :LPAREN
        @next_token = @lexer.next_token()
      else
        error("#{@lexer.line}:#{@lexer.char}: '(' is inserted.")
      end

      varName = parse_Term()

      if @next_token.kind == :COMMA
        @next_token = @lexer.next_token()
      else
        error("#{@lexer.line}:#{@lexer.char}: ',' is inserted.")
      end

      if @next_token.kind == :INTEGER
        relative = @next_token.value
        @next_token = @lexer.next_token()
      end

      if @next_token.kind == :RPAREN
        @next_token = @lexer.next_token()
      else
        error("#{@lexer.line}:#{@lexer.char}: ')' is inserted.")
      end

      return RS::CSP::Text::FunctionTerm.new("U", varName, relative)
    else
      error("#{@lexer.line}:#{@lexer.char}: unexpected token '#{@next_token.value}'.")
      return RS::CSP::Text::IdTerm.new("_")
    end
  end

  private
  # 制約定義を構文解析する。
  # @return [RS::CSP::Text::ConstraintExpression] 制約定義
  # @example 対応する生成規則
  #  ConDefStmt := 'constraint' (Term ('==' | '!=') Term | ('bow' | 'eow') '(' Term ')' ) ';' # 2012/10/29 変更 新井
  def parse_ConDefStmt()
    if @next_token.kind == :CONSTRAINT
      @next_token = @lexer.next_token()
    else
      error("#{@lexer.line}:#{@lexer.char}: 'constraint' is inserted. R")
    end

    cname = "_"
    v1 = nil
    v2 = nil
    ### 2012/10/27 新井 : BW EW を扱えるように変更
    if @next_token.kind == :ID || @next_token.kind == :U_FUNCTION

      v1 = parse_Term()

      if @next_token.kind == :EQ_CON
        cname = "eq" # @next_token.value
        @next_token = @lexer.next_token()
      elsif @next_token.kind == :NE_CON
        cname = "ne" # @next_token.value
        @next_token = @lexer.next_token()
      else
        error("#{@lexer.line}:#{@lexer.char}: '==' or '!=' is expected. T")
      end

      v2 = parse_Term()

    elsif @next_token.kind == :BW_FUNCTION || @next_token.kind == :EW_FUNCTION
      cname = @next_token.value
      @next_token = @lexer.next_token()

      if @next_token.kind == :LPAREN
        @next_token = @lexer.next_token()
      else
        error("#{@lexer.line}:#{@lexer.char}: '(' is inserted.")
      end

      v1 = parse_Term()

      if @next_token.kind == :RPAREN
        @next_token = @lexer.next_token()
      else
        error("#{@lexer.line}:#{@lexer.char}: ')' is inserted.")
      end

    else
      error("#{@lexer.line}:#{@lexer.char}: Term or 'bow' or 'eow' is expected. T")
    end

    if @next_token.kind == :SEMICOLON
      @next_token = @lexer.next_token()
    else
      error("#{@lexer.line}:#{@lexer.char}: ';' is inserted. V")
    end

    # [:ne , xxx ,"!"] と同じ優先度に設定 新井
    return RS::CSP::Text::ConstraintExpression.new(cname, [v1, v2], 1)
  end
end
