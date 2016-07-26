# -*- coding: utf-8 -*-
require 'set'
require 'rubygems'
require 'csp/satisfaction'
require 'composer/fu_cr_composer'
require 'pp'
#$KCODE="u"
#coding:utf-8

# 指定された充足度の(測り方の)下で、良い読みを合成する。
# @see CSP::Evaluator::SatisfactionFactory
# @see CSP::Evaluator::Satisfaction
class RS::Composer::BetterCRComposer < RS::Composer::CompleteReadingComposerBase

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
    startTime = Time.now
    @starts_with = {} # ある変数から始まる読み
    @readings.each {|r|
      if @starts_with[r.vars.first] == nil
        @starts_with[r.vars.first] = [r]
      else
        @starts_with[r.vars.first].push(r)
      end
    }
    createdStartsWith = Time.now - startTime
    puts "created starts_with time (sec) : #{createdStartsWith}"
    @count_clear = 0 # ベターな解集合クリア回数
    @count_add_satisfaction = 0 # ベターな解集合への追加回数
    @job_num = 0
  end

  private
  # 不可読文字数を数える。
  # @param [Array<RS::CSP::ReadingAssignment>] readings 読みの割り当て結果
  # @todo count_unreadablesと類似した処理があるので、それらをまとめる。
  def count_unreadables(readings)
    return ((readings.collect {|x| x.reading}).flatten.select {|x| x == RS::UNREADABLE_CHAR}).size
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
    heads.each { |h|
#      r = (@readings.find_all { |r| h == r[0][0] })
      if @starts_with[h]
        r = @starts_with[h]
      else
        r = []
      end
      (r.sort {|a,b| @unreadables[a] <=> @unreadables[b] }).each { |current_reading|

#        print(@count_node, "\t node:", h,"\t current_reading:")
#        p current_reading

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

  private
  # 読みを合成する。連結した制約グラフの中から1つを選び、{#_compose}によって、その制約グラフの読みの割り当てを探索する。
  # @param [Array<Symbol>] heads 読み始める変数の列
  # @param [Array<Array<Symbol>>] remaining_head_groups 残りの制約グラフの最上流変数列の列
  # @param [Array<RS::CSP::ReadingAssignment>] assigned 探索中に選択した読みの割り当て
  # @param [CSP::Evaluator::Satisfaction] satisfaction 充足度
  # @note 割り当て結果は @result に記録される。
  def _select_next_head_group(headGroups, assigned, satisfaction)
    if headGroups.size == 0
      # 解が構成できた。
      # これ以上は訪問しない。
      if @best_satisfaction == nil || @best_satisfaction < satisfaction
        @best_satisfaction = satisfaction
        @result.clear
        @count_clear += 1
        puts "#{@job_num} : result clear (added satisfaction #{@count_add_satisfaction})"
        @count_add_satisfaction = 0
        @job_num += 1
      end
      if @best_satisfaction == satisfaction
        @result.add(assigned)
        @count_add_satisfaction += 1
        #puts "#{@job_num} : add satisfaction"
        @job_num += 1
      end
    else
      # Fail-First Principleを考慮すべきか？
      # 次にどのグループを選ぶかによって探索の効率が変わるかも。
      nextHeadGroup = headGroups[0]
      remaining_head_groups = headGroups[1..headGroups.size-1]
      _compose(nextHeadGroup, remaining_head_groups, assigned, satisfaction)
    end
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
      base_solutions = RS::Composer::FewerUnreadablesCRComposer.new(@csp, @readings).compose
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
    puts "visit node : #{@count_node}"
    puts "clear : #{@count_clear}"
    return [@result]
  end
end

