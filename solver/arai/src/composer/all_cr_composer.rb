# -*- coding: utf-8 -*-
require 'set'
require 'rubygems'
#$KCODE="u"
#coding:utf-8

#
# 全ての完全な読みを合成する。
# 制約グラフは連結していることを仮定している。
#
class RS::Composer::AllCRComposer < RS::Composer::CompleteReadingComposerBase

  public
  # コンストラクタ
  # @param [CSP::ConstraintSatisfactionProblem] csp 制約充足問題
  # @param [Array<RS::CSP::ReadingAssignment>] readings 読みの割り当て結果
  def initialize(csp, readings)
    @csp = csp
    @heads = csp.heads
    @readings = readings
  end

  private
  # 読みを合成する。{#compose}から呼ばれる。
  # @param [Array<Symbol>] heads 読み始める変数の列
  # @param [Array<RS::CSP::ReadingAssignment>] assigned 探索中に選択した読みの割り当て
  # @note 割り当て結果は @result に記録される。
  def _compose(heads, assigned)
    heads.each { |h|
      (@readings.find_all { |r| h == r.vars.first }).each { |current_reading|
        if @csp.tails.include?(current_reading.vars.last)
          @result.add(assigned + [current_reading])
        else
          next_heads = @csp.decendent_vars_of(current_reading.vars.last)
          _compose(next_heads, assigned + [current_reading])
        end
      }
    }
  end

  public
  # 読みを合成する。
  # @return [Array(Set<Array<RS::CSP::ReadingAssignments>>)] 読みの割り当て結果の集合の配列。配列の要素数は1。
  def compose
    @result = Set.new
    _compose(@heads, [])
    return [@result]
  end
end
