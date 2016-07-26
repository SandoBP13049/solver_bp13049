# -*- coding: utf-8 -*-
require 'set'
require 'rubygems'
require 'csp/satisfaction'
require 'composer/count_constraint_fu_cr_composer'
require 'pp'
#$KCODE="u"
#coding:utf-8

# 指定された充足度の(測り方の)下で、良い読みを合成する。
# 探索時に制約数の少ないノードをたどる。
# @see CSP::Evaluator::SatisfactionFactory
# @see CSP::Evaluator::Satisfaction
class RS::Composer::SelectNodeCRComposer < RS::Composer::BetterCRComposer

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
    @constraint_of = {} # ある変数より下流にある制約
    @count_clear = 0 # ベターな解集合クリア回数
    @count_add_satisfaction = 0 # ベターな解集合への追加回数
    @job_num = 0
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
    heads.sort{|a,b| compare_variable(a,b) }.each { |h|
#    heads.sort_by{|a| @constraint_of[a]}.each { |h|
#      r = (@readings.find_all { |r| h == r[0][0] })
      if @starts_with[h]
        r = @starts_with[h]
      else
        r = []
      end
     # (r.sort {|a,b| @unreadables[a] <=> @unreadables[b] }).each { |current_reading|
      (r.sort {|a,b| compare_variable_array(a.vars, b.vars) }).each { |current_reading|
      #  print(@count_node, "\t node:", h ,"\t constraints:", @constraint_of[current_reading.vars], "\t current_reading:", current_reading.inspect, "\n")

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
      cc_fucr_composer = RS::Composer::CountConstraintFUCRComposer.new(@csp, @readings)
      @constraint_of = cc_fucr_composer.constraint_of
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
    puts "count constraint :: visit node : #{@count_node}"
    puts "clear : #{@count_clear}"

    return [@result]
  end
end
