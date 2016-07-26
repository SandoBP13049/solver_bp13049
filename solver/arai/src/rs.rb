# -*- coding: utf-8 -*-

#
# 翻刻解消器 (Reprint Solver)
#
module RS
  # 仮名ではない文字。漢字など。
  NOT_KANA = "?"
  # 任意の文字 (仮名、漢字を問わない。踊り字制約のために使用されている。)
  ANY_CHAR = "@"
  # 不可読文字
  UNREADABLE_CHAR = "!"
  # 踊り字1 (直前の一文字の繰り返し)
  ODORIJI_1 = "ゝ"
  # 踊り字2 (直前の二文字の繰り返し)
  ODORIJI_2 = "々"
  # 単語内の位置
  UNKNOWN = 8
  END_OF_WORD = 4
  MIDDLE_OF_WORD = 2
  BEGIN_OF_WORD = 1
end

# オープンクラスを用いてStringに属性を付加する。
# Hash< Symbol, Object >

class String
  attr_accessor :attr
    
  public
  # 属性を追加する。
  def add_attr(key, var)
    init_attr
    @attr[key] = var
  end

  public
  # 属性値を考慮したハッシュ
  def hash
    init_attr
    pack_u = to_s.unpack("U*") # stringをutf-8でアンパック
    pack_u.hash + @attr.hash
  end

  public
  # 属性値を考慮したeql
  def eql?(other)
    return false if !(String === other)
    init_attr
    (other.to_s == to_s) && @attr.eql?(other.attr)
  end

  public
  # @attr が定義されていない場合 空のhashを定義する.
  def init_attr
    @attr = {} if @attr == nil
  end

  public
  # 自身を表す文字列と属性値を配列で返す
  def to_valuation
    init_attr
    return [to_s , @attr.to_a].flatten
  end
end

require 'csp/csp'
require 'dictionary/dictionary'
require 'assignor/assignor'
require 'rewriter/rewriter'
require 'composer/composer'


