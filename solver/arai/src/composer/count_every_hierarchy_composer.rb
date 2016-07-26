# -*- coding: utf-8 -*-
require 'set'
require 'rubygems'
require 'csp/satisfaction'
require 'composer/every_hierarchy_cc_fu_cr_composer'
require 'pp'
#$KCODE="u"
#coding:utf-8

# 指定された充足度の(測り方の)下で、良い読みを合成する。
# 探索時に制約数の少ないノードをたどる。
# @see CSP::Evaluator::SatisfactionFactory
# @see CSP::Evaluator::Satisfaction
class RS::Composer::CountEveryHierarchyCRComposer < RS::Composer::BetterCRComposer

  public
  # コンストラクタ
  # @param [CSP::ConstraintSatisfactionProblem] csp 制約充足問題
  # @param [Array<RS::CSP::ReadingAssignment>] readings 読みの割り当て結果
  # @param [CSP::Evaluator::SatisfactionFactory] 充足度のファクトリ
  def initialize(csp, readings, satisfaction_factory)
    @csp = csp
    @head_groups = csp.head_groups
    @readings = readings
    @satisfaction_factory = satisfaction_factory
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
    @every_hierarchy = {} # ある変数より下流にある制約
    @count_clear = 0 # ベターな解集合クリア回数
    @count_add_satisfaction = 0 # ベターな解集合への追加回数
    @job_num = 0
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
  # ある連結した制約グラフについて読みを合成する。その読みを1つ合成したら、{#_select_next_head_group}によって、次の連結した制約グラフの処理に移る。
  # @param [Array<Symbol>] heads 読み始める変数の列
  # @param [Array<Array<Symbol>>] remaining_head_groups 残りの制約グラフの最上流変数列の列
  # @param [Array<RS::CSP::ReadingAssignment>] assigned 探索中に選択した読みの割り当て
  # @param [CSP::Evaluator::Satisfaction] satisfaction 充足度
  def _compose(heads, remaining_head_groups, assigned, satisfaction)
    #訪れたノード？
    @count_node += 1
    #puts "#{@job_num} : _compose in"
    @job_num += 1
    heads.sort{|a,b| compare_variable(a , b) }.each{ |h|
#      r = (@readings.find_all { |r| h == r[0][0] })
      if @starts_with[h]
        r = @starts_with[h]
      else
        r = []
      end
      #(r.sort {|a,b| @unreadables[a] <=> @unreadables[b] }).each { |current_reading|
      (r.sort {|a,b| compare_variable_array(a.vars , b.vars) }).each { |current_reading|

       # puts "#{@count_node}, \t node:, #{h.inspect} ,\t constraints:\t #{@every_hierarchy[current_reading.vars].inspect} \t current_reading:\t #{current_reading.inspect}"
        current_satisfaction = satisfaction.add_reading(current_reading)
        if current_satisfaction.admissible? == false
          next
        end
        if @best_satisfaction != nil && (@best_satisfaction.comparable?(current_satisfaction) == false || @best_satisfaction > current_satisfaction)
          next
        end
        if @csp.tails.include?(current_reading.vars.last)
          _select_next_head_group(remaining_head_groups, assigned + [current_reading], current_satisfaction)
        else
          nextHeads = @csp.decendent_vars_of(current_reading.vars.last)
          _compose(nextHeads, remaining_head_groups, assigned + [current_reading], current_satisfaction)
        end
      }
    }
    #puts "#{@job_num} : _compose out"
    @job_num += 1
  end

  public
  # 読みを合成する。
  # @return [Array<Set<Array<RS::CSP::ReadingAssignemnt>>>] 読みの割り当て結果の集合の配列。集合の個数は1。
  def compose
    @count_node = 0
    if true
      # 簡単な手法で基本となる解の充足度を求める。
      # 最終的に求めたい解はそれと同等もしくはこれ以上に良い充足度を持つ解。
      # 分岐限定法をより効果的にしたい。
      base_satisfaction = @satisfaction_factory.create(@csp.constraints)
      cc_fucr_composer = RS::Composer::EveryHierarchyCCFUCRComposer.new(@csp, @readings)
      @every_hierarchy = cc_fucr_composer.every_hierarchy
      base_solutions = cc_fucr_composer.compose
      base_solutions.each {|r| # ある連結グラフの解の集合
        r.first.each {|s| # RS::CSP::ReadingAssignmentのインスタンス
            base_satisfaction = base_satisfaction.add_reading(s)
        }
      }
      @best_satisfaction = base_satisfaction
    else
      @best_satisfaction = nil
    end
    @result = Set.new
    satisfaction = @satisfaction_factory.create(@csp.constraints)
    _select_next_head_group(@head_groups, [], satisfaction)
    puts "every hierarchy :: visit node : #{@count_node}"
    puts "clear : #{@count_clear}"
    return [@result]
  end

end
