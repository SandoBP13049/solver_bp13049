#!/opt/local/bin/ruby
# -*- coding: utf-8 -*-
require 'set'
#$KCODE="u"

#
# 制約の評価器
#
# @note 制約階層 {http://www.cs.washington.edu/research/constraints/theory/hierarchies-92.html}
#
module RS::CSP::Evaluator

  #
  # 制約が評価不能であることを表す例外
  #
  class NotEvaluableException < Exception; end

  #
  # 不正な関数名であることを表す例外
  #
  class InvalidFunctionNameException < Exception; end
  
  #
  # 引数の個数が間違っていることを表す例外
  #
  class WrongNumberOfArgumentsException < Exception; end

  #
  # 不正な式であることを表す例外
  #
  class UnknownExpressionException < Exception; end

  #
  # 指定された充足度との和が計算できないことを表す例外
  #
  class UnableToAddStatisfactionsException < Exception; end

  #
  # 制約クラス
  #
  class Constraint 
    # 属性を増やしたら、#eql?と#hashも更新すべきかを検討する。

    # @return [Integer] 制約の優先度(強度) 0, 1, 2, ...
    attr_reader :strength
    # @return [Array] 制約式
    # @example
    #  [:eq, :x1, :x2]
    attr_reader :expression 
    # @return[Set<:Symbol>] この制約が参照する変数の集合
    attr_reader :involved_variables

    public
    # 他のオブジェクトとの比較
    def eql?(other)
      if (Constraint === other) == false
        return false
      end
      return @strength.eql?(other.strength) && @expression.eql?(other.expression) && @involved_variables.eql?(other.involved_variables)
    end

    public
    # ハッシュ関数
    def hash
      return @strength.hash + @expression.hash + @involved_variables.hash
    end

    public
    # コンストラクタ
    #
    # @param [Integer] strength 制約の優先度0, 1, 2, ...
    # @param [Array] expression 制約式
    # @example
    #  c = Constraint.new(0, [:eq, :x1, :x2])
    #
    def initialize(strength, expression)
      @strength = strength
      @expression = expression
      @involved_variables = Set.new(collect_vars())
    end

    private
    # 制約式が構文的に参照する変数を集める。{#collect_vars}から呼ばれる。
    #
    # @param [Array] expression 制約式
    # @return [Array<Symbol>] 変数の配列
    # @todo クラスメソッドにする。
    def _collect_vars(expression)
      if Symbol === expression   # 変数
        return [expression]
      elsif Array === expression # 関数適用
        func = expression[0]
        result = []
        expression[1..expression.length-1].each {|subExpression|
          result = result + _collect_vars(subExpression)
        }
        return result
      end
      return []
    end

    public
    # この制約が構文的に参照する変数を集める。
    #
    # @return [Array<Symbol>] 変数の配列
    # @example
    #  c = Constraint.new(0, [:eq, [:U, :x1, 2], :x2])
    #  c.collect_vars() #=> [:x1, :x2]
    def collect_vars()
      return _collect_vars(@expression)
    end

    public
    # 付値の下で評価可能?
    #
    # @param [Array<Array(Symbol, String)>] valuation 付値(変数名と値の組の配列 [[変数名, 値], [変数名, 値], ...])
    # @return [true, false] valuationの下で評価可能ならtrue, そうでなければfalse
    # @example
    #  bindng = [[:x1, "あ"], [:x2, "い"]]
    #  c = Constraint.new(0, [:eq, :x1, :x2])
    #  c.evaluable?(valuation) #=> true
    def evaluable?(valuation)
      return @involved_variables.subset?(Set.new(valuation.map {|x| x[0]}))
    end

    public
    # このオブジェクトを文字列化する。
    # @return [String] 強度と制約式を含む文字列
    def to_s
      result = "strength: #{@strength}, constraint: #{@expression.inspect}"
    end

    private
    # 制約式を評価する。{#eval}から呼ばれる。
    #
    # @param [Array] expression 制約式
    # @param [Array<Array(Symbol, String)>] valuation 付値(変数名と値の組の配列 [[変数名, 値], [変数名, 値], ...])
    # @return [true, false] 充足されているならtrue, そうでなければfalse
    # @example
    #  bindng = [[:x1, "あ"], [:x2, "い"]]
    #  c = Constraint.new(0, [:eq, :x1, :x2])
    #  c.eval_expression([:eq, :x1, :x2], valuation) #=> false
    # @todo クラスメソッドにする。
    def eval_expression(expression, valuation)
      if Symbol === expression   # 変数
        pair = valuation.assoc(expression)
        if pair == nil
          return RS::ANY_CHAR
        end
        return pair[1]
      elsif Numeric === expression   #  数値
        return expression
      elsif String === expression   #  文字列
        return expression
      elsif Array === expression # 関数適用
        func = expression[0]
        args = []
        expression[1..expression.length-1].each {|subExp|
          a = eval_expression(subExp, valuation)
          if a == nil
            raise NotEvaluableException
          end
          args.push(a)
        }
        case func
        when :eq   # :== ではsyntax errorになる。
          if args.length != 2
            raise WrongNumberOfArgumentsException
          end
          if args[0] == args[1] || args[0] == RS::ANY_CHAR || args[1] == RS::ANY_CHAR
            return true
          else
            return false
          end
        when :ne   # :!= ではsyntax errorになる。
          if args.length != 2
            raise WrongNumberOfArgumentsException
          end
          if args[0] != args[1] || args[0] == RS::ANY_CHAR || args[1] == RS::ANY_CHAR
            return true
          else
            return false
          end
        when :U
          var_order = valuation.map {|x| x[0]} # 構築したパス上の変数列
          i = var_order.index(expression[1]) # [:U v n]の場合, expression[1] == v
          if i == nil 
            return RS::ANY_CHAR # not applicable
          end
          j = i - args[1]
          if j < 0 || j >= var_order.length
            return RS::ANY_CHAR # the domain of an imaginary variable
          end
          return eval_expression(var_order[j], valuation) # 上流の変数の値
        when :true
          if args.length != 0
            raise WrongNumberOfArgumentsException
          end
          return true
        when :false
          if args.length != 0
            raise WrongNumberOfArgumentsException
          end
          return false
        # 2012/10/30 BoW EoW を追加 : 新井
        when :bow
          if args.length != 1
            raise WrongNumberOfArgumentsException
          end
          chr = eval_expression(args[0], valuation)
          #puts "#{expression[1]} : #{chr.attr[:position]} & RS::BEGIN_OF_WORD == #{RS::BEGIN_OF_WORD} => #{chr.attr[:position] & RS::BEGIN_OF_WORD == RS::BEGIN_OF_WORD}"
          if chr.attr[:position] & RS::BEGIN_OF_WORD == RS::BEGIN_OF_WORD
            return true
          end
          return false
        when :eow
          if args.length != 1
            raise WrongNumberOfArgumentsException
          end
          chr = eval_expression(args[0], valuation)
          #puts "#{expression[1]} : #{chr.attr[:position]} & RS::END_OF_WORD == #{RS::END_OF_WORD} => #{chr.attr[:position] & RS::END_OF_WORD == RS::END_OF_WORD}"
          #p ":word = #{chr.attr[:word]} :word.length = #{chr.attr[:word].split(//).length}"
          if chr.attr[:position] & RS::END_OF_WORD == RS::END_OF_WORD
            return true
          end
          return false
        else
          raise InvalidFunctionNameException
        end
      end
      raise UnknownExpressionException
    end

    public
    # 制約式を評価する。
    #
    # @param [Array<Array(Symbol, String)>] valuation 付値(変数とその値の組の列 [[変数名, 値], [変数名, 値], ... ])
    # @return [true, false] 制約が充足されているか評価不能ならtrue, 制約が充足されていないならfalse
    # @example
    #  bindng = [[:x1, "あ"], [:x2, "い"]]
    #  c = Constraint.new(0, [:eq, :x1, :x2])
    #  c.eval(valuation) #=> false
    def eval(valuation)
      begin
        return eval_expression(@expression, valuation)
      rescue NotEvaluableException
        return true
      end
    end

  end

  # @abstract
  # Satisfcationのfactoryクラス
  #
  # {RS::Composer::BetterCRComposer} や {RS::Composer::HashedBetterCRComposer} のコンストラクタに、
  # このクラスのサブクラスを渡すことで、探索に用いる解の比較器を変更できるようにする。
  class SatisfactionFactory; end

  # @abstract
  # 充足度
  class Satisfaction; end
    
  #
  # UCBSatisfcationのfactoryクラス
  #
  # @see RS::CSP::Evaluator::UCBSatisfaction
  class UCBSatisfactionFactory < SatisfactionFactory
    public
    # UCBSatisfcationクラスを作成する。
    # @param [Array<Array<Array>>] hierarchy 制約階層
    # @return [RS::CSP::Evaluator::UCBSatisfaction] UCBSatisfactionのインスタンス
    # @example
    #   h = [ [ [:eq, :x1, :x2], [:ne, :x2, :x3] ],  # 優先度(強度) 0
    #         [ [:eq, :x1, :x2], [:ne, :x2, :x3] ],  # 優先度(強度) 1
    #         [ [:eq, :x1, :x2], [:ne, :x2, :x3] ]]  # 優先度(強度) 2
    #   s = UCBSatisfactionFactory.new.create(h) # sはUCBSatisfcationクラスのインスタンス
    def create(hierarchy=[])
      UCBSatisfaction.new(hierarchy)
    end
  end

  #
  # Unsatisfied-count-betterによる充足度
  # @note Unsatisfied-count-better {http://www.cs.washington.edu/research/constraints/theory/hierarchies-92.html}
  # @see RS::CSP::Evaluator::UCBSatisfactionFactory
  class UCBSatisfaction < Satisfaction
    # @return [Set<Array>] 評価可能な制約の集合
    attr_accessor :evaluable_constraints
    # @return [Set<Array>] 評価不能な制約の集合
    attr_accessor :inevaluable_constraints
    # @return [Array<Array<Symbol, String>>] 変数とその値の組の列 [[変数名, 値], [変数名, 値], ... ]
    attr_accessor :valuation
    # @return [Array<Integer>] 階層ごとの誤差の列
    attr_accessor :error

    public
    # コンストラクタ
    #
    # @param [Array<Array<Array>>] hierarchy 制約階層
    # @example
    #   h = [ [ [:eq, :x1, :x2], [:ne, :x2, :x3] ],  # 優先度(強度) 0
    #         [ [:eq, :x1, :x2], [:ne, :x2, :x3] ],  # 優先度(強度) 1
    #         [ [:eq, :x1, :x2], [:ne, :x2, :x3] ]]  # 優先度(強度) 2
    #   s = UCBSatisfaction.new(h)
    def initialize(hierarchy=[])
      constraints = Set.new
      @valuation = []

      0.upto(hierarchy.length-1).each {|strength|
        hierarchy[strength].each {|expression|
          constraints.add(RS::CSP::Evaluator::Constraint.new(strength, expression))
        }
      }

      @evaluable_constraints = constraints.select {|c|
        c.evaluable?(@valuation)
      }
      @inevaluable_constraints = constraints - @evaluable_constraints

      @error = [ ].fill(0, 0, hierarchy.length)

      @evaluable_constraints.each {|c|
        @error[c.strength] += 1 if c.eval(@valuation) == false
      }
    end

    public
    # 読みを追加した結果の新しい充足度オブジェクトを作成する。
    # 
    # @param [RS::CSP::Reading] reading 追加する読み
    # @return [RS::CSP::Evaluator::UCBSatisfaction] 読みを追加した充足度
    # @example
    #  s = UCBSatisfaction.new
    #  r = RS::CSP::ReadingAssignment.new([:x1, :x2], 'あい', 0)
    #  s = s.add_reading(r)
    def add_reading(reading)
      valuation = @valuation.dup # [[変数名, 値], [変数名, 値], ... ]
      reading.to_valuation.each {|v|
        valuation.push(v)
      }

      additional_constraints = @inevaluable_constraints.select {|c| c.evaluable?(valuation)}

      error = @error.dup
      additional_constraints.each {|c|
        error[c.strength] += 1 if c.eval(valuation) == false
      }

      result = UCBSatisfaction.new
      result.evaluable_constraints = @evaluable_constraints + additional_constraints
      result.inevaluable_constraints = @inevaluable_constraints - additional_constraints
      result.valuation = valuation
      result.error = error

      return result
    end

    public
    # 他のSatisfactionとの和を計算する。和を表す新規のオブジェクトを生成する。
    # 
    # @param [RS::CSP::Evaluator::UCBSatisfaction] other 他のUCBSatisfactionオブジェクト
    # @return [RS::CSP::Evaluator::UCBSatisfaction] このオブジェクトとotherとの和を表す新規のUCBSatisfactionオブジェクト
    # @example
    #  s = UCBSatisfaction.new
    #  t = UCBSatisfaction.new
    #  ....
    #  u = s + t # uはs, tとは異なる新規オブジェクト
    def +(other)
      if (@valuation.map {|p| p[0]} & other.valuation.map {|p| p[0]}).size > 0
        raise UnableToAddStatisfactionsException  # ある変数に複数の値が割り当てられている。
      end
      if @error.size != other.error.size
        raise UnableToAddStatisfactionsException  # 階層の深さが違う。
      end

      valuation = @valuation + other.valuation

      common_inevaluable_constraints = @inevaluable_constraints & other.inevaluable_constraints
      additional_constraints = common_inevaluable_constraints.select {|c| c.evaluable?(valuation)}

      error = ([@error, other.error].transpose).map {|p| p.inject(0){|result, i| result + i }}
      additional_constraints.each {|c|
        error[c.strength] += 1 if c.eval(valuation) == false
      }

      result = UCBSatisfaction.new
      result.evaluable_constraints = @evaluable_constraints + other.evaluable_constraints + additional_constraints
      result.inevaluable_constraints = common_inevaluable_constraints - additional_constraints
      result.valuation = valuation
      result.error = error
    end

    public
    # 文字列化メソッド
    # @return [String] 評価可能な制約、評価不能な制約、付値(変数から値への写像), 誤差を表す文字列
    def to_s
      result = ""
      result += "evaluable:\n"
      @evaluable_constraints.each {|c|
        result += "      #{c.to_s}\n"
      }
      result += "inevaluable:\n"
      @inevaluable_constraints.each {|c|
        result += "      #{c.to_s}\n"
      }
      result += "valuation: #{@valuation.inspect}\n"
      result += "error: #{@error.inspect}\n"
      return result
    end

    public
    # このオブジェクトの方が、他のRS::CSP::Evaluator::UCBSatisfactionオブジェクトよりも充足度が高い?
    #
    # @param [RS::CSP::Evaluator::UCBSatisfaction] other 比較対象となるRS::CSP::Evaluator::UCBSatisfactionオブジェクト
    # @return [true, false] このオブジェクトの方が充足度が高ければtrue, そうでなければfalse。
    def >(other)
      0.upto(@error.length-1).each {|i|
        if @error[i] < other.error[i]
          return true
        end
        if @error[i] > other.error[i]
          return false
        end
      }
      return false # どれも等しい
    end

    public
    # このオブジェクトの方が、他のRS::CSP::Evaluator::UCBSatisfactionオブジェクトよりも充足度が高いもしくは同程度?
    #
    # @param [RS::CSP::Evaluator::UCBSatisfaction] other 比較対象となるRS::CSP::Evaluator::UCBSatisfactionオブジェクト
    # @return [true, false] このオブジェクトの方が充足度が高いもしくは同程度ならばtrue, そうでなければfalse。
    def >=(other)
      return !(self < other)
    end

    public
    # このオブジェクトの方が、他のRS::CSP::Evaluator::UCBSatisfactionオブジェクトよりも充足度が低い?
    #
    # @param [RS::CSP::Evaluator::UCBSatisfaction] other 比較対象となるRS::CSP::Evaluator::UCBSatisfactionオブジェクト
    # @return [true, false] このオブジェクトの方が充足度が低ければtrue, そうでなければfalse。
    def <(other)
      0.upto(@error.length-1).each {|i|
        if @error[i] < other.error[i]
          return false
        end
        if @error[i] > other.error[i]
          return true
        end
      }
      return false # どれも等しい
    end

    public
    # このオブジェクトの方が、他のRS::CSP::Evaluator::UCBSatisfactionオブジェクトよりも充足度が低いもしくは同程度?
    #
    # @param [RS::CSP::Evaluator::UCBSatisfaction] other 比較対象となるRS::CSP::Evaluator::UCBSatisfactionオブジェクト
    # @return [true, false] このオブジェクトの方が充足度が低いもしくは同程度ならばtrue, そうでなければfalse。
    def <=(other)
      return !(self > other)
    end

    public
    # このオブジェクトの充足度は、他のRS::CSP::Evaluator::UCBSatisfactionオブジェクトと同程度?
    #
    # @param [RS::CSP::Evaluator::UCBSatisfaction] other 比較対象となるRS::CSP::Evaluator::UCBSatisfactionオブジェクト
    # @return [true, false] このオブジェクトの充足度が同程度ならばtrue, そうでなければfalse。
    def ==(other)
      if other == nil
        return false
      end
      0.upto(@error.length-1).each {|i|
        if @error[i] != other.error[i]
          return false
        end
      }
      return true # どれも等しい
    end

    public
    # 許容解?
    #
    # @return [true, false] 許容解(評価可能なrequired制約を全て充足している)ならtrue。そうでなければfalse。
    def admissible?() 
      return @error[0] == 0 # required制約を未充足としていない。
    end

    def comparable? (other)
      return true
    end
  end


  #
  # LPBSatisfcationのfactoryクラス
  #
  # @see RS::CSP::Evaluator::LPBSatisfaction
  class LPBSatisfactionFactory < SatisfactionFactory
    public
    # UCBSatisfcationクラスを作成する。
    # @param [Array<Array<Array>>] hierarchy 制約階層
    # @return [RS::CSP::Evaluator::LPBSatisfaction] LPBSatisfactionのインスタンス
    # @example
    #   h = [ [ [:eq, :x1, :x2], [:ne, :x2, :x3] ],  # 優先度(強度) 0
    #         [ [:eq, :x1, :x2], [:ne, :x2, :x3] ],  # 優先度(強度) 1
    #         [ [:eq, :x1, :x2], [:ne, :x2, :x3] ]]  # 優先度(強度) 2
    #   s = LPBSatisfactionFactory.new.create(h) # sはUCBSatisfcationクラスのインスタンス
    def create(hierarchy=[])
      LPBSatisfaction.new(hierarchy)
    end
  end

  #
  # locally-predicate-betterによる充足度
  # @note locally-predicate-better {http://www.cs.washington.edu/research/constraints/theory/hierarchies-92.html}
  # @see RS::CSP::Evaluator::LPBSatisfactionFactory
  class LPBSatisfaction < Satisfaction
    # @return [Set<Array>] 評価可能な制約の集合
    attr_accessor :evaluable_constraints
    # @return [Set<Array>] 評価不能な制約の集合
    attr_accessor :inevaluable_constraints
    # @return [Array<Array<Symbol, String>>] 変数とその値の組の列 [[変数名, 値], [変数名, 値], ... ]
    attr_accessor :valuation
    # @return [Array<Integer>] 階層ごとの誤差の列
    attr_accessor :error

    public
    # コンストラクタ
    #
    # @param [Array<Array<Array>>] hierarchy 制約階層
    # @example
    #   h = [ [ [:eq, :x1, :x2], [:ne, :x2, :x3] ],  # 優先度(強度) 0
    #         [ [:eq, :x1, :x2], [:ne, :x2, :x3] ],  # 優先度(強度) 1
    #         [ [:eq, :x1, :x2], [:ne, :x2, :x3] ]]  # 優先度(強度) 2
    #   s = LPBSatisfaction.new(h)
    def initialize(hierarchy=[])
      constraints = Set.new
      @valuation = []

      0.upto(hierarchy.length-1).each {|strength|
        hierarchy[strength].each {|expression|
          constraints.add(RS::CSP::Evaluator::Constraint.new(strength, expression))
        }
      }

      @evaluable_constraints = constraints.select {|c|
        c.evaluable?(@valuation)
      }
      @inevaluable_constraints = constraints - @evaluable_constraints

      @error = [ ]
      0.upto(hierarchy.length-1).each {|strength|
        @error[strength] = Set.new
      }

      @evaluable_constraints.each {|c|
        @error[c.strength].add(c) if c.eval(@valuation) == false
      }
    end

    public
    # 読みを追加した結果の新しい充足度オブジェクトを作成する。
    # 
    # @param [RS::CSP::Reading] reading 追加する読み
    # @return [RS::CSP::Evaluator::LPBSatisfaction] 読みを追加した充足度
    # @example
    #  s = LPBSatisfaction.new
    #  r = RS::CSP::ReadingAssignment.new([:x1, :x2], 'あい', 0)
    #  s = s.add_reading(r)
    def add_reading(reading)
      valuation = @valuation.dup # [[変数名, 値], [変数名, 値], ... ]
      reading.to_valuation.each {|v|
        valuation.push(v)
      }

      additional_constraints = @inevaluable_constraints.select {|c| c.evaluable?(valuation)}

      error = @error.dup
      additional_constraints.each {|c|
        error[c.strength] = error[c.strength] + Set.new.add(c) if c.eval(valuation) == false
      }

      result = LPBSatisfaction.new
      result.evaluable_constraints = @evaluable_constraints + additional_constraints
      result.inevaluable_constraints = @inevaluable_constraints - additional_constraints
      result.valuation = valuation
      result.error = error

      return result
    end

    public
    # 他のSatisfactionとの和を計算する。和を表す新規のオブジェクトを生成する。
    # 
    # @param [RS::CSP::Evaluator::LPBSatisfaction] other 他のLPBSatisfactionオブジェクト
    # @return [RS::CSP::Evaluator::LPBSatisfaction] このオブジェクトとotherとの和を表す新規のLPBSatisfactionオブジェクト
    # @example
    #  s = LPBSatisfaction.new
    #  t = LPBSatisfaction.new
    #  ....
    #  u = s + t # uはs, tとは異なる新規オブジェクト
    def +(other)
      if (@valuation.map {|p| p[0]} & other.valuation.map {|p| p[0]}).size > 0
        raise UnableToAddStatisfactionsException  # ある変数に複数の値が割り当てられている。
      end
      if @error.size != other.error.size
        raise UnableToAddStatisfactionsException  # 階層の深さが違う。
      end

      valuation = @valuation + other.valuation

      common_inevaluable_constraints = @inevaluable_constraints & other.inevaluable_constraints
      additional_constraints = common_inevaluable_constraints.select {|c| c.evaluable?(valuation)}

      error = []
      0.upto(@error.length-1).each {|strength|
        error[strength] = @error[strength] + other.error[strength]
      }
      additional_constraints.each {|c|
        error[c.strength] = error[c.strength] + Set.new.add(c) if c.eval(valuation) == false
      }

      result = LPBSatisfaction.new
      result.evaluable_constraints = @evaluable_constraints + other.evaluable_constraints + additional_constraints
      result.inevaluable_constraints = common_inevaluable_constraints - additional_constraints
      result.valuation = valuation
      result.error = error
    end

    public
    # 文字列化メソッド
    # @return [String] 評価可能な制約、評価不能な制約、付値(変数から値への写像), 誤差を表す文字列
    def to_s
      result = ""
      result += "evaluable:\n"
      @evaluable_constraints.each {|c|
        result += "      #{c.to_s}\n"
      }
      result += "inevaluable:\n"
      @inevaluable_constraints.each {|c|
        result += "      #{c.to_s}\n"
      }
      result += "valuation: #{@valuation.inspect}\n"
      result += "error: #{@error.inspect}\n"
      return result
    end

    public
    # このオブジェクトの方が、他のRS::CSP::Evaluator::LPBSatisfactionオブジェクトよりも充足度が高い?
    #
    # @param [RS::CSP::Evaluator::LPBSatisfaction] other 比較対象となるRS::CSP::Evaluator::LPBSatisfactionオブジェクト
    # @return [true, false] このオブジェクトの方が充足度が高ければtrue, そうでなければfalse。
    def > (other)
      0.upto(@error.length-1).each {|i|
        if @error[i].proper_subset?(other.error[i])
          return true
        end
        if @error[i] == other.error[i]
         next
        end
        return false
      }
      return false # どれも等しい
    end

    public
    # このオブジェクトの方が、他のRS::CSP::Evaluator::LPBSatisfactionオブジェクトよりも充足度が高いもしくは同程度?
    #
    # @param [RS::CSP::Evaluator::LPBSatisfaction] other 比較対象となるRS::CSP::Evaluator::LPBSatisfactionオブジェクト
    # @return [true, false] このオブジェクトの方が充足度が高いもしくは同程度ならばtrue, そうでなければfalse。
    def >=(other)
      return self > other || self == other
    end

    public
    # このオブジェクトの方が、他のRS::CSP::Evaluator::LPBSatisfactionオブジェクトよりも充足度が低い?
    #
    # @param [RS::CSP::Evaluator::LPBSatisfaction] other 比較対象となるRS::CSP::Evaluator::LPBSatisfactionオブジェクト
    # @return [true, false] このオブジェクトの方が充足度が低ければtrue, そうでなければfalse。
    def <(other)
      0.upto(@error.length-1).each {|i|
        if other.error[i].proper_subset?(@error[i])
          return true
        end
        if @error[i] == other.error[i]
         next
        end
        return false
      }
      return false # どれも等しい
    end

    public
    # このオブジェクトの方が、他のRS::CSP::Evaluator::LPBSatisfactionオブジェクトよりも充足度が低いもしくは同程度?
    #
    # @param [RS::CSP::Evaluator::LPBSatisfaction] other 比較対象となるRS::CSP::Evaluator::LPBSatisfactionオブジェクト
    # @return [true, false] このオブジェクトの方が充足度が低いもしくは同程度ならばtrue, そうでなければfalse。
    def <=(other)
      return self < other || self == other
    end

    public
    # このオブジェクトの充足度は、他のRS::CSP::Evaluator::LPBSatisfactionオブジェクトと同程度?
    #
    # @param [RS::CSP::Evaluator::LPBSatisfaction] other 比較対象となるRS::CSP::Evaluator::LPBSatisfactionオブジェクト
    # @return [true, false] このオブジェクトの充足度が同程度ならばtrue, そうでなければfalse。
    def ==(other)
      if other == nil
        return false
      end
      0.upto(@error.length-1).each {|i|
        if (@error[i] == other.error[i]) == false
          return false
        end
      }
      return true # どれも等しい
    end

    public
    # 許容解?
    #
    # @return [true, false] 許容解(評価可能なrequired制約を全て充足している)ならtrue。そうでなければfalse。
    def admissible?() 
      return @error[0].empty? # required制約を未充足としていない。
    end

    def comparable? (other)
      0.upto(@error.length-1).each {|i|
        if @error[i].proper_subset?(other.error[i])
          return true
        end
        if other.error[i].proper_subset?(@error[i])
          return true
        end
        if @error[i] == other.error[i]
         next
        end
        return false # 包含関係にない階層がある。
      }
      return true
    end
  end

end # end of the module RS::CSP::Evaluator
