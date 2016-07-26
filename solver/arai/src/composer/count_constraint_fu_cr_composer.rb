# -*- coding: utf-8 -*-
require 'set'
require 'rubygems'
require 'csp/normalizer'
#$KCODE="u"
#coding:utf-8

#
# なるべくRS::UNREADABLE_CHAR (不可読文字)を含まない読みを合成する。
# 制約数の少ないノードから探索する
class RS::Composer::CountConstraintFUCRComposer < RS::Composer::CompleteReadingComposerBase
  attr_accessor :constraint_of
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
    @constraint_of = {} # ある変数より下流にある制約
    @topological_order = RS::CSP::VariableSorter.new(@csp).tsort
    @topological_order.each {|node|
      # nodeを含む読みの割り当て
      @readings.select{|reading| reading.vars.include?(node)}.each{|r|
        if @constraint_of[r.vars] == nil
          count_constraint(r.vars)
        end
      }
    }
    countedConstraintTime = Time.now - startTime
    puts "count constraints (sec) : #{countedConstraintTime}"
    #puts "@constraint_of = "
    #pp @constraint_of
  end

  private
  # ある変数より下流にある制約数を数える
  # @param var <Symbol> 変数名
  # @param count
  def count_constraint(var)
    # nodeより下流を列挙
    under = @csp.decendent_vars_of(var.last)
    # varを構文上参照している制約の集合
    constraints = Set.new
    var.each{|n| constraints.add( @csp.constraints_on(n) )}
    constraints = constraints.flatten
    # varを構文上参照している制約数
    @constraint_of[var] = constraints.size
    # 末端でない
    if under.size > 0
      tmp = 0
      under.each{|v| @starts_with[v].select{|read| @constraint_of[read.vars] == nil}.each{|r| count_constraint(r)}}
     # under.select{|v| @constraint_of[v] == nil}.each{|n| count_constraint(n)}
      under.each{|v| @starts_with[v].each{|r|
          if tmp < @constraint_of[r.vars]
            tmp = @constraint_of[r.vars]
          end
        }
      }
      @constraint_of[var] += tmp
    end
  end

  private
  def compare_variable_array(var1, var2)
    return @constraint_of[var1] <=> @constraint_of[var2]
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
    heads.sort{|a,b| compare_variable(a,b) }.each { |h|
      if @starts_with[h]
        r = @starts_with[h]
      else
        r = []
      end
      (r.sort {|a,b| @unreadables[a] <=> @unreadables[b]}).each { |currentReading|
      #(r.sort {|a,b| compare_variable_array(a,b) }).each { |currentReading|
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
    result = []
    @head_groups.map {|heads|
      @result = Set.new
      @min_unreadables = @max_min_unreadables
      _compose(heads, [])
      result.push(@result)
    }
    return result
  end
end
