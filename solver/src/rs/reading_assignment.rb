# -*- coding: utf-8 -*-

#
# 読みの割り当て
#
class RS::CSP::ReadingAssignment
  # @return [Array<Symbol>] 変数列
  # @example [:x1, :x2, :x3]
  attr_reader :vars 
  # @return [String] 単語
  # @example "あいう"
  attr_reader :word
  # @return [Integer] 単語の読み始め位置 (0, 1, 2, ...)
  attr_reader :start
  # @return [Array<String>] 変数列に割り当てた文字の列
  attr_reader :reading

  public
  # コンストラクタ
  # @param [Array<Symbol>] vars 変数列
  # @param [String] word 単語
  # @param [Integer] start 単語の読み始め位置 (0, 1, 2, ...)
  # @example 次の場合、変数列[:x1, :x2, :x3]に、単語"あいうえお"の1文字目からの3文字"いうえ"が、重なることを意味する。
  #  ra = RS::CSP::ReadingAssignment.new([:x1, :x2, :x3], "あいうえお", 1)
  def initialize(vars, word, start)
    @vars = vars
    @word = word
    @start = start
    @reading = word.split(//)[start, @vars.size]
  end
  
  public
  def init_pos
    pos = @start
    tail = (@word.split(//).length - 1)
    @reading.each{|c|
      if c == RS::UNREADABLE_CHAR
        c.add_attr(:position, RS::UNKNOWN ) # "!" の場合
      elsif tail + pos == 0
        c.add_attr(:position, RS::BEGIN_OF_WORD | RS::END_OF_WORD) # 一文字の単語
      elsif pos + tail == tail
        c.add_attr(:position, RS::BEGIN_OF_WORD)        # 先頭
      elsif pos == tail
        c.add_attr(:position, RS::END_OF_WORD)        # 末尾
      elsif pos != tail && pos != 0
        c.add_attr(:position, RS::MIDDLE_OF_WORD)       # 中腹
      end
      pos += 1
      #puts "#{w.vars.inspect} : #{w.reading.inspect} : #{c} : #{c.attr.inspect}"
    }
    #puts "#{@word} : #{to_reading_attribute.inspect}" if @vars.include?(:x1)
  end
  
  public
  # 配列化
  # @return [Array(Array<Symbol>, Array<String>, Integer)] このオブジェクトの内容
  def to_a
    return [@vars, @reading]
  end

  public
  # 文字列化
  # @return [String] このオブジェクトの内容
  def to_s
    return to_a.to_s
  end

  public
  # 付値(変数とその値との組の列)を得る。
  # @return [Array(Array<Symbol, String>)] 付値(valuation)
  def to_valuation
    #puts "@vars = #{@vars.inspect}"
    #puts "@reading = #{@reading.inspect}"
    return [@vars, @reading].transpose
  end

  public
  # @return [String] このオブジェクトの内容
  def inspect
    #return to_a.inspect
    return to_reading_attribute.inspect
  end

  public
  # 他のオブジェクトとの比較
  def eql?(obj)
    if (RS::CSP::ReadingAssignment === obj) == false
      return false
    end
    return @vars.eql?(obj.vars) && @reading.eql?(obj.reading)
  end

  public
  # ハッシュ関数
  def hash
    return @vars.hash + @reading.hash
  end

  public
  # @return [Array( Array<Symbol>, Array<String>, Array< Hash<Symbol,int> > )] 単語中の位置を表す属性値を含む配列
  def to_reading_attribute
    reading_attribute = to_a
    attrs = []
    reading_attribute[1].each{|r|
      attrs << r.attr
    }
   # puts "attrs : #{attrs.inspect}"
    reading_attribute.push(attrs)
    return reading_attribute
  end
end
