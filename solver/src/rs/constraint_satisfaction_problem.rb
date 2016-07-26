# -*- coding: utf-8 -*-
require 'set'
require 'rubygems'

# 制約充足問題
#
# ハッシュ表現のラッパークラス
#
# @example 制約充足問題のハッシュ表現
#  {
#   :vars=>{ # 変数とその領域
#           :_11=>["た"], :_30=>["に"], :_14=>["れ"], :_08=>["ち"], :_16=>["へ", "つ", "は"],
#           :_01=>["み"], :_29=>["ん", "く"], :_03=>["の"], :_21=>["そ", "ろ"], :_05=>["の"],
#           :_24=>["し"], :_18=>["み"], :_26=>["な"], :_10=>["り", "わ"], :_28=>["ら"], :_13=>["す"],
#           :_07=>["を", "も"], :_15=>["ゆ"], :_09=>["す"], :_17=>["よ", "に"], :_02=>["ち"], :_20=>["れ"],
#           :_04=>["つ", "く"], :_23=>["よ", "に"], :_22=>["め"], :_06=>["!"], :_25=>["!"], :_19=>["こ", "さ", "た"],
#           :_27=>["ら", "く"], :_12=>["!"]
#          },
#    :connectivity=>[ # 制約グラフの辺。変数のDAG (Directed Acyclic Graph, 有向非循環グラフ)をなす。
#                    [:_01, :_02], [:_02, :_03], [:_03, :_04], [:_04, :_05], [:_05, :_06], [:_06, :_07],
#                    [:_07, :_08], [:_08, :_09], [:_09, :_10], [:_10, :_11], [:_10, :_12], [:_11, :_14],
#                    [:_13, :_14], [:_14, :_15], [:_15, :_16], [:_16, :_17], [:_17, :_18], [:_18, :_19],
#                    [:_19, :_20], [:_20, :_21], [:_21, :_22], [:_22, :_23], [:_23, :_24], [:_24, :_25],
#                    [:_25, :_26], [:_26, :_27], [:_27, :_28], [:_28, :_29], [:_29, :_30], [:_12, :_13]
#                   ],
#    :constraints=>[ # 制約階層
#                   [  # 優先度0
#                   ],
#                   [  # 優先度1
#                    [:ne, :_23, "!"], [:ne, :_12, "!"], [:ne, :_01, "!"], [:ne, :_24, "!"], [:ne, :_13, "!"],
#                    [:ne, :_02, "!"], [:ne, :_25, "!"], [:ne, :_14, "!"], [:ne, :_03, "!"], [:ne, :_26, "!"],
#                    [:ne, :_15, "!"], [:ne, :_04, "!"], [:ne, :_27, "!"], [:ne, :_16, "!"], [:ne, :_05, "!"],
#                    [:ne, :_28, "!"], [:ne, :_17, "!"], [:ne, :_06, "!"], [:ne, :_30, "!"], [:ne, :_29, "!"],
#                    [:ne, :_18, "!"], [:ne, :_07, "!"], [:ne, :_20, "!"], [:ne, :_19, "!"], [:ne, :_08, "!"],
#                    [:ne, :_21, "!"], [:ne, :_10, "!"], [:ne, :_09, "!"], [:ne, :_22, "!"], [:ne, :_11, "!"]
#                   ]
#                  ]
#  }
class RS::CSP::ConstraintSatisfactionProblem
  # @return [Array<Symbol>] 制約充足問題に現れる全ての変数の列
  # @example 3つの変数:x1, :x2, :x3だけが現れる場合
  #  [:x1, :x2, :x3]
  attr_reader :vars 
  # @return [Hash{Symbol=>Array<String>}] 各変数とその領域との対応
  # @example 変数:x1の領域は!{"あ", "い"}, 変数:x2の領域は!{"う"}の場合
  #  {:x1=>["あ", "い"], :x2=>["う"]}
  attr_reader :domains
  # @return [Set<Array<Symbol, Symbol>>] 配列 [変数1, 変数2]の集合。
  #  全体で変数のDAG(Directed Acyclic Graph, 有向非循環グラフ)をなす。
  # @example 変数:x1の後に変数:x2が続くことを表す配列
  #  [:x1, :x2]
  attr_reader :connectivity
  # @return [Array<Symbol>] 制約グラフの先頭にある変数(上流の変数を持たない変数)の列
  # @example 変数:x1と変数:x2が制約グラフの先頭であることを表す配列
  #  [:x1, :x2]
  attr_reader :heads 
  # @return [Array<Symbol>] 制約グラフの末尾にある変数(下流の変数を持たない変数)の列
  # @example 変数:x1と変数:x2が制約グラフの末尾であることを表す配列
  #  [:x1, :x2]
  attr_reader :tails
  # @return [Array<Array<Array>>] 制約階層。配列(制約)の配列(階層)の配列。
  # @example 制約階層
  #  [
  #   [[:eq, :x1, :x2], [:eq, :x3, :x4]],   # 最も優先される制約の階層
  #   [[:ne, :x1, "!"], [:ne, :x2, "!"], [:ne, :x3, "!"], [:ne, :x4, "!"] # 最も弱い制約の階層
  #  ]
  attr_reader :constraints

  public
  #
  # コンストラクタ
  #
  # @param [Hash] csp_hash CSPのハッシュ表現
  #
  def initialize(csp_hash)
    @vars = csp_hash[:vars].keys.sort {|x,y| x.to_s <=> y.to_s}
    @domains = csp_hash[:vars].dup
    @connectivity = Set.new csp_hash[:connectivity].dup
    @heads = @vars.dup
    @tails = @vars.dup
    @connectivity.each do |c| # [from, to] 
      @heads = @heads - [c[1]] # to
      @tails = @tails - [c[0]] # from
    end
    @decendent_vars_of = {} # 変数->直後の変数の配列
    @ascendent_vars_of = {} # 変数->直前の変数の配列
    @connectivity.each {|cn|
      if @decendent_vars_of[cn[0]] == nil
        @decendent_vars_of[cn[0]] = [cn[1]]
      else
        @decendent_vars_of[cn[0]].push(cn[1])
      end
      if @ascendent_vars_of[cn[1]] == nil
        @ascendent_vars_of[cn[1]] = [cn[0]]
      else
        @ascendent_vars_of[cn[1]].push(cn[0])
      end
    }

    @constraints = csp_hash[:constraints]
    @odoriji = csp_hash[:odoriji]
  end

  private
  #
  # 意味的に、制約に参照されている変数の列
  #
  # @param [Array] expression  制約式
  # @return [Array] 変数列  
  # @example
  #  vars_referenced_by([:eq, [:U, :x1, 1], :x2]) #=> [:x1の1つ上流の変数, :x2]
  def vars_referenced_by(expression)
    if Symbol === expression # 変数名
      return [expression]
    elsif Numeric === expression # 定数(数値)
      return []
    elsif String ===  expression # 定数(文字列)
      return []
    elsif Array === expression # [関数名, 引数1, 引数2, 引数n]
      func = expression[0]
      args = expression[1..expression.length-1]
      case func
      when :eq
        return args.map {|a| vars_referenced_by(a)}.flatten
      when :ne
        return args.map {|a| vars_referenced_by(a)}.flatten
      when :U  # [:U v n]
        vars = [ args[0] ]
        n = args[1]
        n.times {|i|
          vars = vars.map {|v| ascendent_vars_of(v)}.flatten.uniq
        }
        return vars
      when :bow, :eow # [:bow, v]
        return vars_referenced_by(args[0])
      when :true
        return []
      when :false
        return []
      end
    end
    return []
  end

  public
  #
  # 構文上、制約が変数を参照している?
  #
  # @param [Array] constraint 制約
  # @param [Symbol] var 変数
  # @return [true, false] constraintがvarを参照していればtrue, そうでなければfalse。
  # @example
  #  constraint_on?([:eq, [:U, :x1, 1], :x2], :x1) #=> true
  #  
  def constraint_on?(constraint, var) 
    if @var_to_constraints == nil # このメソッドが初めて呼ばれたときに実行する。
      @var_to_constraints = {} # 変数->制約の集合
      @constraints.each {|h| # 1つの階層
        h.each {|c| # 制約
          vars_referenced_by(c).each {|v|
            if @var_to_constraints[v] == nil
              @var_to_constraints[v] = Set.new
            end
            @var_to_constraints[v].add(c)
          }
        }
      }
    end
    return @var_to_constraints[var].include?(constraint)
  end

  public
  #
  # 構文上、変数varを参照している制約の集合
  #
  # @param [Symbol] var 変数
  # @return [Set<Array>] varを参照している制約の集合。各制約は配列で表現される。
  # @example
  #  constraints_on(:x1) #=> 変数:x1を参照している制約の集合
  # @see #constraint_on?
  def constraints_on(var) 
    if @var_to_constraints == nil  # このメソッドが初めて呼ばれたときに実行する。
      @var_to_constraints = {} # 変数->制約の集合
      @constraints.each {|h| # 1つの階層
        h.each {|c| # 制約
          vars_referenced_by(c).each {|v|
            if @var_to_constraints[v] == nil
              @var_to_constraints[v] = Set.new
            end
            @var_to_constraints[v].add(c)
          }
        }
      }
    end
    return @var_to_constraints[var] # 2回目以降の呼び出しでは、この行だけを実行する。
  end

  public
  #
  # 変数varの直後(すぐ下流)の変数の集合(配列)
  #
  # @param [Symbol] var 変数
  # @return [Array<Symbol>] varの直後の変数の集合
  #
  def decendent_vars_of(var)
    if @decendent_vars_of[var] != nil
      return @decendent_vars_of[var]
    end
    return []
  end

  private
  #
  # 変数varの下流にある末尾の変数(下流の変数を持たない変数)の集合(配列)
  #
  # @param [Symbol] var 変数
  # @return [Array<Symbol>] varの下流にある末尾の変数の集合
  def all_tail_vars_from(var)
    if @all_tail_vars_from == nil
      @all_tail_vars_from = {}
    end
    if @all_tail_vars_from[var] == nil
      result = []
      frontLine = [var]
      previous = 0
      hub = []
      visited = []
      while frontLine.size > 0
        ## 2以上のノードから1つのノードに集約した場合
        #if previous > 1 && frontLine.size == 1
        #  # 既にハブを通った末端がわかっている
        #  if @all_tail_vars_from[frontLine.first] != nil
        #    @all_tail_vars_from[var] = @all_tail_vars_from[frontLine.first]
        #    return @all_tail_vars_from[var]
        #  end
        #  hub << frontLine.first
        #end
        previous = frontLine.size
        visited = visited | frontLine
        #puts "visited:#{visited.inspect}"
        result = result | (frontLine & @tails)
        frontLine = ((frontLine.map {|x| decendent_vars_of(x)}).flatten - visited ).uniq
        #puts "frontLine:#{frontLine}"
      end
      @all_tail_vars_from[var] = result
      # ハブからは同じ末端にいく
      # hub.each{|v| @all_tail_vars_from[v] = result }
    end
    return @all_tail_vars_from[var]
  end
  
  public
  #
  # 先頭の変数(上流の変数を持たない変数)を、下流を共有する変数毎に分類した結果を返す。
  #
  # @return [Set] 各要素は、共有する下流変数を持つ先頭の変数の集合
  #
  def head_groups
    if @head_groups == nil
      tails = {}
      @heads.each { |x|
        tails[x] = all_tail_vars_from(x)
      }
      @head_groups = (Set.new(@heads).divide { |o1, o2| (tails[o1] & tails[o2]).size > 0 }).to_a
    end
    #puts "head_groups:#{@head_groups.inspect}"
    return @head_groups
  end

  public
  #
  # ある変数の直前の変数(すぐ上流の変数)の集合(配列)
  #
  # @param [Symbol] var 変数
  # @return [Array<Symbol>] varの直前の変数の集合
  #
  def ascendent_vars_of(var)
    if @ascendent_vars_of[var] != nil
      return @ascendent_vars_of[var]
    end
    return []
  end

  private
  #
  # 制約グラフにおいて、変数varから下流へつながる長さlengthのパスの集合。varは含まれない。
  # {#var_path_from}メソッドから呼ばれる。
  #
  # @param [Symbol] var 変数
  # @param [Integer] length 変数列長
  # @param [Integer] reach パスの何文字目?(0, 1, 2, 3, ...)。再帰呼び出しの終了条件に用いる。
  # @return [Set<Array<Symbol>>] varからつながる長さlengthの変数列の集合。varは含まれない。
  def _var_path_from(var, length, reach)
    if length < reach
      return Set.new [ [] ]
    end

    if length == reach || @tails.include?(var)
      return Set.new [ [var] ]
    end

    # length > reach
    result = Set.new
    decendent_vars_of(var).each do |dvar|
      pset = _var_path_from(dvar, length, reach+1)
      result = result + pset.map {|p| [var] + p}
    end
    return result
  end

  public
  #
  # 制約グラフにおいて、varから下流へつながる長さlengthのパスの集合。varは含まれない。
  #
  # @param [Symbol] var 変数
  # @param [Integer] length 変数列長
  # @return [Set<Array<Symbol>>] varからつながる長さlengthの変数列の集合。varは含まれない。
  #
  def var_path_from(var, length)
    result = Set.new
    decendent_vars_of(var).each do |dvar|
      result = result + _var_path_from(dvar, length, 1)
    end
    if result.size == 0
      result.add([])
    end
    return result
  end

  private
  #
  # 制約グラフにおいて、上流から変数varにつながる長さlengthのパスの集合。varは含まれない。
  # {#var_path_to}メソッドから呼ばれる。
  #
  # @param [Symbol] var 変数
  # @param [Integer] length 変数列長
  # @param [Integer] reach パスの何文字目?(0, 1, 2, 3, ...)。再帰呼び出しの終了条件に用いる。
  # @return [Set<Array<Symbol>>] varにつながる長さlengthの変数列の集合。varは含まれない。
  def _var_path_to(var, length, reach)
    if length < reach
      return Set.new [ [] ]
    end

    if length == reach || @heads.include?(var)
      return Set.new [ [var] ]
    end

    # length > reach
    result = Set.new
    ascendent_vars_of(var).each do |avar|
      pset = _var_path_to(avar, length, reach+1)
      result = result + pset.map {|p| p + [var]}
    end
    return result
  end

  public
  #
  # 制約グラフにおいて、上流からvarにつながる長さlengthのパスの集合。varは含まれない。
  #
  # @param [Symbol] var 変数
  # @param [Integer] length 変数列長
  # @return [Set<Array<Symbol>>] varにつながる長さlengthの変数列の集合。varは含まれない。
  # 
  def var_path_to(var, length)
    result = Set.new
    ascendent_vars_of(var).each do |avar|
      result = result + _var_path_to(avar, length, 1)
    end
    if result.size == 0
      result.add([])
    end
    return result
  end

  public
  #
  # varを含む長さlengthのパスの集合
  #
  # @param [Symbol] var 変数
  # @param [Integer] length 変数列長
  # @return [Set<Array<Symbol>>] varを含む長さlengthのパスの集合
  #
  def var_path(var, length)
    result = Set.new
    up_length = length -1 # 上流側の長さ
    down_length = 0 # 下流側の長さ
    while up_length >= 0 do
      upPaths = var_path_to(var, up_length)
      downPaths = var_path_from(var, down_length)
      upPaths.each do |x|
        downPaths.each do |y|
          result.add(x + [var] + y)
        end
      end
      up_length -= 1
      down_length += 1
    end
    return result
  end
end
