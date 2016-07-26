# -*- coding: utf-8 -*-
require 'set'
require 'rubygems'
require 'csp/satisfaction'
require 'composer/fu_cr_composer'
#$KCODE="u"
#coding:utf-8

#
# 連結した制約グラフごとに、指定された充足度の(測り方の)下で、良い読みを合成する。連結した制約グラフ間の制約は無視される。
# @see CSP::Evaluator::SatisfactionFactory
# @see CSP::Evaluator::Satisfaction
#
class RS::Composer::HashedBetterCRComposer < RS::Composer::CompleteReadingComposerBase
  public
  # コンストラクタ
  # @param [CSP::ConstraintSatisfactionProblem] csp 制約充足問題
  # @param [Array<RS::CSP::ReadingAssignment>] readings 読みの割り当て結果  [ 変数列, 仮名の列 ]の列
  # @param [CSP::Evaluator::SatisfactionFactory] 充足度のファクトリ
  def initialize(csp, readings, satisfaction_factory)
    @csp = csp
    @head_groups = csp.head_groups
    @readings = readings
    @result = Set.new
    @best_satisfaction = nil
    @satisfaction_factory = satisfaction_factory
  end

  private
  # 読みを合成する。{#compose}から呼ばれる。
  # @param [Array<Symbol>] heads 読み始める変数の列
  # @param [Array<RS::CSP::ReadingAssignment>] assigned 探索中に選択した読みの割り当て  [ 変数列, 仮名の列 ]の列
  # @note 割り当て結果は @result に記録される。
  # @todo RS::Composer::FewerUnreadablesCRComposer#count_unreadables のような関数を導入する。
  def _compose(heads, assigned, satisfaction)
    heads.each { |h|
      r = (@readings.find_all { |r| h == r.vars.first })
      (r.sort {|a,b| (a.reading.select {|x| x == RS::UNREADABLE_CHAR}).size <=> (b.reading.select {|x| x == RS::UNREADABLE_CHAR}).size }).each { |current_reading|
        current_satisfaction = satisfaction.add_reading(current_reading)
        if current_satisfaction.admissible? == false
          next
        end
        if @best_satisfaction != nil && (@best_satisfaction.comparable?(current_satisfaction) == false || @best_satisfaction > current_satisfaction)
          next
        end
        if @csp.tails.include?(current_reading.vars.last)
          if @best_satisfaction == nil || @best_satisfaction < current_satisfaction
            @best_satisfaction = current_satisfaction
            @result.clear
          end
          if @best_satisfaction == current_satisfaction
            @result.add(assigned + [current_reading])
          end
        else
          nextHeads = @csp.decendent_vars_of(current_reading.vars.last)
          _compose(nextHeads, assigned + [current_reading], current_satisfaction)
        end
      }
    }
  end

  public
  # 読みを合成する。
  # @return [Array<Set<Array<RS::CSP::ReadingAssignment>>>] 読みの割り当て結果の集合の配列。配列の要素数は、連結した制約グラフの個数。
  def compose
    result = []
    @head_groups.map {|heads|
      if false
        # 簡単な手法で基本となる解の充足度を求める。
        # 最終的に求めたい解はそれと同等もしくはこれ以上に良い充足度を持つ解。
        # 分岐限定法をより効果的にしたい。
        base_satisfaction = @satisfaction_factory.create(@csp.constraints)
        composer = RS::Composer::FewerUnreadablesCRComposer.new(@csp, @readings)
        base_solutions = composer.compose_from(heads)
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
      _compose(heads, [], satisfaction)
      result.push(@result)
    }
    return result
  end
end
