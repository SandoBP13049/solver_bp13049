# -*- coding: utf-8 -*-
require 'set'
#$KCODE="u"
#coding:utf-8

#
# 読みの割り当てグラフにおいて、直列する読みの割り当てを併合するクラス
#
# 表記
# * 変数列(v_1, ..., v_n)への読み(a_1, ..., a_n)の割り当てを、((v_1, ..., v_n), (a_1, ..., a_n)) で表現することにする。
#
# 処理
#
# 読みの割り当てグラフにおいて、読みの割り当てグラフに変化がなくなるまで、次の処理を繰り返す。
# * ノードxはノードyの唯一の親でありかつyはxの唯一の子である場合、2つのノードxとyを、xとyを併合した1つのノードに置き換える。
# * 例えば、ノードxを((v_1, ..., v_n), (a_1, ..., a_n))、ノードyを((w_1, ..., w_m), (b_1, ..., b_m))とすると、xとyを併合したノードは((v_1, ..., v_n, w_1, ..., w_m), (a_1, ..., a_n, b_1, ..., b_m))
#
# 効果
# * 読みの合成器が処理するノード数が減る。
#
# 考慮すべき事項
# * 単語の切れ目を破壊する。
class RS::Rewriter::SequentialRAMerger < RS::Rewriter::RewriterBase

  public
  # 読みの割り当てグラフにおいて、直列する読みの割り当てを併合する。
  # @param [CSP::ConstraintSatisfactionProblem] csp 制約充足問題
  # @param [Array<RS::CSP::ReadingAssignment>] readings 読みの割り当て
  # @return [Array<RS::CSP::ReadingAssignment>] 書き換え結果
  def translate(csp, readings)
    vars = readings.map {|r| r.vars}.flatten.uniq # 読みの割り当てに出現する変数の列
    current_readings = Set.new(readings)
    result_readings = nil
    while(true)
      result_readings = current_readings.dup
      current_readings.each {|r| # 注目する読みの割り当てr
        if result_readings.include?(r) == false
          next
        end
        dec_vars = csp.decendent_vars_of(r.vars.last)
        decendents = result_readings.select {|q| dec_vars.include?(q.vars.first)} # rに続く読みの割り当ての列
        if decendents.size != 1
          next
        end
        # rのすぐ下流には、たった1つの読みの割り当てがある。
        decendent = decendents.first

        asc_vars = csp.ascendent_vars_of(decendent.vars.first)
        ascendents = result_readings.select {|q| asc_vars.include?(q.vars.last)}
        if ascendents.size != 1
          next
        end
        # decendentのすぐ上流には、たった1つの読みの割り当て(つまりr)がある。

        result_readings.delete(decendent)
        result_readings.delete(r)
        new_vars = r.vars + decendent.vars
        new_word = (r.reading + decendent.reading).join('')
        new_reading = RS::CSP::ReadingAssignment.new(new_vars, new_word, 0)
        old_word = r.reading + decendent.reading
        0.upto(new_reading.reading.length-1){|i|
          new_reading.reading[i].attr = old_word[i].attr.dup
        }
        #puts "#{new_reading.to_reading_attribute}"
        result_readings.add(new_reading)
      }
      if (current_readings == result_readings)
        break
      end
      current_readings = result_readings
    end
    return result_readings.to_a
  end
end
