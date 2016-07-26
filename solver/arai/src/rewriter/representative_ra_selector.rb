# -*- coding: utf-8 -*-
require 'set'
#$KCODE="u"
#coding:utf-8

#
# 代表的な読みの割り当てを選択するクラス
#
# 表記
# * 変数列(v_1, ..., v_n)への読み(a_1, ..., a_n)の割り当てを、((v_1, ..., v_n), (a_1, ..., a_n)) で表現することにする。
#
# 処理
#
# 読みの割り当てグラフにおいて、読みの割り当てグラフに変化がなくなるまで、次の処理を繰り返す。
#
# ある変数xについて、変数xを参照する唯一の制約 変数x != 定数a が存在するならば、
# * U := \{(( x ), ( c )) | c = a}、Uの任意の要素をuとし、任意の読みの割り当てr∈U-\{u} を取り除く。(制約を充足しない代表的な読みの割り当てuを選択する。)
# * S := \{(( x ), ( c )) | c != a}、Sの任意の要素をsとし、任意の読みの割り当てr∈S-\{s} を取り除く。(制約を充足する代表的な読みの割り当てsを選択する。)
#
# ある変数xについて、変数xを参照する唯一の制約 変数x = 定数a が存在するならば、
# * U := \{(( x ), ( c )) | c != a}、Uの任意の要素をuとし、任意の読みの割り当てr∈U-\{u} を取り除く。(制約を充足しない代表的な読みの割り当てuを選択する。)
# * S := \{(( x ), ( c )) | c = a}、Sの任意の要素をsとし、任意の読みの割り当てr∈S-\{s} を取り除く。(制約を充足する代表的な読みの割り当てsを選択する。)
#
# 効果
# * 探索空間を削減する。
#
# 考慮すべき事項
# * 最適解の一部だけを選択するので、人間から見た場合の正解が削除される可能性がある。
class RS::Rewriter::RepresentativeRASelector < RS::Rewriter::RewriterBase

  public
  # 並列しているノードを併合した結果を返す。
  # @param [CSP::ConstraintSatisfactionProblem] csp 制約充足問題
  # @param [Array<RS::CSP::ReadingAssignment>] readings 読みの割り当て
  # @return [Array<RS::CSP::ReadingAssignment>] 書き換え結果
  def translate(csp, readings)
    Set.new(readings).classify {|r| r.vars}.map {|k,v|
      merge_parallel_nodes_with_same_variable_path(csp, v.to_a)
    }.inject([]) {|s,i| s+i}
  end

  private
  # 変数列の長さが1の場合について、可能ならば併合する(代表的な読みだけを残す)。
  # @param [CSP::ConstraintSatisfactionProblem] csp 制約充足問題
  # @param [Array<RS::CSP::ReadingAssignment>] readings 変数列の等しい読みの配列
  # @return [Array<RS::CSP::ReadingAssignment>] readings 書き換え結果
  def merge_parallel_nodes_with_same_variable_path(csp, readings)
    if readings.size < 2 # 読みの個数が2未満
      return readings
    end
    if readings.first.vars.size != 1 # 変数列の長さが1ではない
      return readings
    end
    # 読みの個数が2以上 && 変数列の長さが1
    var = readings.first.vars.first # 変数列の唯一の変数
    cons = csp.constraints_on(var).to_a # varを参照している制約の列
    if cons.size > 1 # varを参照している制約が2つ以上ある
      return readings
    end
    if cons.size == 0 # varを参照している制約がない
      representative = readings[0]
      return [ representative ]
    end
    # 変数varを参照している制約は、唯一
    c = cons[0]
    case c[0]
    when :ne
      if c[1] == var
        val = c[2]
      else
        val = c[1]
      end
      if !(String === val)
        return readings
      end
      # その制約は [:ne var val] or [:ne val var], valは文字定数

      unsatisfied_readings = readings.select {|r| r.reading.first == val}
      satisfied_readings = readings.select {|r| r.reading.first != val} # readings - unsatisfied_readings

      representative_readings = []
      if unsatisfied_readings.size > 0
        representative_readings += [unsatisfied_readings.first]
      end
      if satisfied_readings.size > 0
        representative_readings += [satisfied_readings.first]
      end
      return representative_readings
    when :eq
      if c[1] == var
        val = c[2]
      else
        val = c[1]
      end
      if !(String === val)
        return readings
      end
      # その制約は [:eq var val] or [:eq val var], valは文字定数

      unsatisfied_readings = readings.select {|r| r.reading.first != val}
      satisfied_readings = readings.select {|r| r.reading.first == val} # readings - unsatisfied_readings

      representative_readings = []
      if unsatisfied_readings.size > 0
        representative_readings += [unsatisfied_readings.first]
      end
      if satisfied_readings.size > 0
        representative_readings += [satisfied_readings.first]
      end
      return representative_readings
    when :true
      representative = readings.first
      return [ representative ]
    when :false
      representative = readings.first
      return [ representative ]
    end
    return readings
  end

end
