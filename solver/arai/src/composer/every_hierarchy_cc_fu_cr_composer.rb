# -*- coding: utf-8 -*-
require 'set'
require 'rubygems'
require 'csp/normalizer'
#$KCODE="u"
#coding:utf-8

#
# なるべくRS::UNREADABLE_CHAR (不可読文字)を含まない読みを合成する。
# 制約数の少ないノードから探索する
class RS::Composer::EveryHierarchyCCFUCRComposer < RS::Composer::CompleteReadingComposerBase
  attr_accessor :every_hierarchy
  public
  # コンストラクタ
  # @param [CSP::ConstraintSatisfactionProblem] csp 制約充足問題
  # @param [Array<RS::CSP::ReadingAssignment>] readings 読みの割り当て結果
  def initialize(csp, readings)
    @csp = csp
    @head_groups = csp.head_groups
    @readings = readings
    @min_unreadables = csp.vars.size
    @max_min_unreadables = csp.vars.size
    @result = Set.new

    @unreadables = {} # 読めない文字の個数
    @readings.each {|r|
      @unreadables[r] = (r.reading.select {|x| x == RS::UNREADABLE_CHAR}).size
    }
    @starts_with = {} # ある変数から始まる読み
    @readings.each {|r|
      if @starts_with[r.vars.first] == nil
        @starts_with[r.vars.first] = [r]
      else
        @starts_with[r.vars.first].push(r)
      end
    }
    startTime = Time.now
    @every_hierarchy = {} # ある変数より下流にある制約
    @topological_order = RS::CSP::VariableSorter.new(@csp).tsort
    @topological_order.each {|node|
      # nodeを含む読みの割り当て
       @readings.select{|reading| reading.vars.include?(node)}.each{|r|
        if @every_hierarchy[r.vars] == nil
          count_constraint(r.vars)
        end
      }
    }
    countedConstraintTime = Time.now - startTime

    puts "count constraints (sec) : #{countedConstraintTime}"
    #puts "@every_hierarchy = "
    #pp @every_hierarchy
  end


  private
  # ある変数より下流にある制約数を数える
  # @param vars Array[<Symbol>] 変数名の配列
  def count_constraint(var)
    #puts "var = #{var.inspect}"
    # nodeより下流を列挙
    under = @csp.decendent_vars_of(var.last)
    #puts "under = #{under.inspect}"
    # varを意味的に参照している制約の集合
    constraints = Set.new
    var.each{|n|
      constraints.add( @csp.constraints_on(n) )
    }
    constraints = constraints.flatten
    #puts "constraints = #{constraints.inspect}"
    # ブロックの条件で分類
    # 返り値:hash  {hierarchy<int> => <Set>} --> {<int> => <int>}
    hash = constraints.classify{|c|
      where_belong(c)
    }
    hash.each{|key, v|
      hash[key] = v.size
    }
    # varを構文上参照している制約数
    @every_hierarchy[var] = hash
    if under.size > 0
      # 末端でない
      tmp = nil
      under.each{|v| @starts_with[v].select{|read| @every_hierarchy[read.vars] == nil}.each{|r|
          if @every_hierarchy[r.vars] == nil
            count_constraint(r.vars)
          end
        }
      }
      under.each{|v| @starts_with[v].each{|r|
          if tmp == nil
            tmp = r
          elsif compare_variable_array(tmp.vars , r.vars) < 0
            tmp = r
          end
        }
      }
      addConstraintCount(var, tmp.vars)
    end
  end

  private
  # var1にvar2の階層別制約数を足し込む
  # @param [Array<Symbol>] var1 変数列
  # @param [Array<Symbol>] var2 変数列
  def addConstraintCount(var1, var2)
    #puts "@every_hierarchy[var2] = #{every_hierarchy[var2].inspect}"
    @every_hierarchy[var2].each{|key, c|
      if @every_hierarchy[var1].key?(key)
        @every_hierarchy[var1][key] += c
        next
      end
      @every_hierarchy[var1][key] = c
    }
  end

  private
  # ある制約がどの階層に属しているかを調べる
  # @param [Array] constraint 1つの制約
  # @return [Integer] 属する階層。どの階層にも属していなければ-1
  def where_belong(constraint)
    hierarchy = 0
    @csp.constraints.each{|h|
      if h.include?(constraint)
        return hierarchy
      end
      hierarchy += 1
    }
    return -1
  end

  private
  # ソートの際に使用する順序を決める
  # @param [Array<Symbol>] var1 変数列
  # @param [Array<Symbol>] var2 変数列
  def compare_variable_array(var1, var2)
   # puts "var1 = "
   # pp var1
   # puts "var2 = "
   # pp var2

    0.upto(@csp.constraints.size-1){|h| #階層
      if !@every_hierarchy[var1].key?(h) && !@every_hierarchy[var2].key?(h)
        next
      end
      if !@every_hierarchy[var1].key?(h)
        return -1
      elsif !@every_hierarchy[var2].key?(h)
        return 1
      end

      if @every_hierarchy[var1][h] < @every_hierarchy[var2][h]
        return -1
      elsif @every_hierarchy[var1][h] > @every_hierarchy[var2][h]
        return 1
      end
    }
    return 0
  end

  private
  def compare_variable(var1, var2)
    v1_best = @starts_with[var1].sort{|a,b| compare_variable_array(a.vars, b.vars)}.first.vars
    v2_best = @starts_with[var2].sort{|a,b| compare_variable_array(a.vars, b.vars)}.first.vars
    return compare_variable_array(v1_best, v2_best)
  end

  private
  # 不可読文字数を数える。
  # @param [Array<RS::CSP::ReadingAssignment>] readings 読みの割り当て結果
  # @todo count_unreadablesと類似した処理があるので、それらをまとめる。
  def count_unreadables(readings)
    return ((readings.collect {|x| x.reading}).flatten.select {|x| x == RS::UNREADABLE_CHAR}).size
  end

  private
  # 読みを合成する。{#compose}から呼ばれる。
  # @param [Array<Symbol>] heads 読み始める変数の列
  # @param [Array<RS::CSP::ReadingAssignment>] assigned 探索中に選択した読みの割り当て
  # @note 割り当て結果は @result に記録される。
  def _compose(heads, assigned)
    @count_node += 1
    heads.sort{|a,b| compare_variable(a, b) }.each { |h|
      if @starts_with[h]
        r = @starts_with[h]
      else
        r = []
      end
      (r.sort {|a,b| @unreadables[a] <=> @unreadables[b]}).each { |currentReading|
        cur = count_unreadables(assigned + [currentReading])
        if cur > @min_unreadables
          next
        end
        if @csp.tails.include?(currentReading.vars.last)
          if cur < @min_unreadables
            @min_unreadables = cur
            @result.clear
          end
          @result.add(assigned + [currentReading])
        else
          nextHeads = @csp.decendent_vars_of(currentReading.vars.last)
          _compose(nextHeads, assigned + [currentReading])
        end
      }
    }
  end

  public
  # 読みを合成する。
  # @param [Array<Symbol>] heads 読みを開始する変数名の列
  # @return [Array(Set<Array<RS::CSP::ReadingAssignment>)] 読みの割り当て結果の集合の配列。配列の要素数は1。
  def compose_from(heads)
    @result = Set.new
    @min_unreadables = @max_min_unreadables
    _compose(heads, [])
    return [@result]
  end

  public
  # 連結した制約グラフ毎に、読みを合成する。
  # @return [Array<Set<Array<RS::CSP::ReadingAssignment>>>] 読みの割り当て結果の集合の配列。配列の要素数は、連結した読みの割り当てグラフの個数。
  def compose
    @count_node = 0
    result = []
    @head_groups.map {|heads|
      @result = Set.new
      @min_unreadables = @max_min_unreadables
      _compose(heads, [])
      result.push(@result)
    }
#    puts "fewer unreadables :: visit node : #{@count_node}"
    return result
  end
end
