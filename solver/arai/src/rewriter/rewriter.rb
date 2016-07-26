# -*- coding: utf-8 -*-
require 'csp/reading_assignment'

#
# 読みの割り当ての書き換え器のモジュール
#
module RS::Rewriter; end

#
# 読みの割り当ての書き換え器の基底クラス
#
class RS::Rewriter::RewriterBase

  public
  # @param [CSP::ConstraintSatisfactionProblem] csp 制約充足問題
  # @param [Array<RS::CSP::ReadingAssignment>] readings 読みの割り当て
  # @return [Array<RS::CSP::ReadingAssignment>] 書き換え結果
  def translate(csp, readings)
    return readings.dup
  end
end

require 'rewriter/representative_ra_selector'
require 'rewriter/sequential_ra_merger'
require 'rewriter/unsatisfiable_ra_remover'
require 'rewriter/ra_shortener'
