# -*- coding: utf-8 -*-

require 'set'

#
# 読みの合成器のモジュール
#
module RS::Composer; end

#
# 完全な読み(complete reading)の合成器の基底クラス
# * テキストの先頭から末尾にいたるパス上の全ての変数への、読みの割り当て結果
#
class RS::Composer::CompleteReadingComposerBase
  public
  # コンストラクタ
  # @param [CSP::ConstraintSatisfactionProblem] csp 制約充足問題
  # @param [Array<RS::CSP::ReadingAssignment>] readings 読みの割り当て結果
  def initialize(csp, readings)
  end

  public
  # 読みを合成する。
  # @return [Array<Set<Array<RS::CSP::ReadingAssignemnt>>>] 読みの割り当て結果の集合の配列
  def compose
    @result = Set.new
    return [@result]
  end
 end

require 'composer/all_cr_composer'
require 'composer/fu_cr_composer'
require 'composer/better_cr_composer'
require 'composer/hashed_better_cr_composer'

require 'composer/select_node_composer'
require 'composer/count_every_hierarchy_composer'
require 'composer/count_constraint_fu_cr_composer'
require 'composer/every_hierarchy_cc_fu_cr_composer'
