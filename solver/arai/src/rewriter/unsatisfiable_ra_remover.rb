# -*- coding: utf-8 -*-
#$KCODE="u"
#coding:utf-8

#
# 制約を満たさない読みの割り当てを削除する。
#
# 表記
# * 変数列(v_1, ..., v_n)への読み(a_1, ..., a_n)の割り当てを、 ((v_1, ..., v_n), (a_1, ..., a_n)) で表現することにする。
#
# 処理
#
# 読みの割り当てグラフのある変数xについて、
# * 変数xに関する最も強い制約がただ1つ存在し、
# * その制約は 変数x != 定数a (もしくは、定数a != 変数x)という形をしており、
# * 読みの割り当て((x), (a))が存在し、
# * 読みの割り当て((x), (定数b_1)), ..., ((x), (定数b_n)) (n>=1, 1<=i<=n, b_i != a)が存在する
# ならば、読みの割り当て((x), (a))を、読みの割り当てグラフから削除する。
#
# 読みの割り当てグラフのある変数xについて、
# * 変数xに関する最も強い制約がただ1つ存在し、
# * その制約は 変数x = 定数a (もしくは、定数a = 変数x)という形をしており、
# * 読みの割り当て((x), (a))が存在し、
# * 読みの割り当て((x), (定数b_1)), ..., ((x), (定数b_n)) (n>=1, 1<=i<=n, b_i != a)が存在する
# ならば、読みの割り当て((x), (b_1)), ..., ((x), (b_n))を、読みの割り当てグラフから削除する。
#
# 効果
# * 探索空間を削減する。
class RS::Rewriter::UnsatisfiableRARemover < RS::Rewriter::RewriterBase

  public
  # 読みの割り当てから RS::UNREADABLE_CHAR を削除する。
  # @param [CSP::ConstraintSatisfactionProblem] csp 制約充足問題
  # @param [Array<RS::CSP::ReadingAssignment>] readings 読みの割り当て
  # @return [Array<RS::CSP::ReadingAssignment>] 書き換え結果
  def translate(csp, readings)
    result_readings = readings.dup
    csp.vars.each {|var|
      # 変数varに関する最も強い制約の配列hを求める。
      h = csp.constraints.map {|h|  # 制約階層の1つの階層
        h.select {|c| csp.constraint_on?(c, var)}  # 変数varを参照する制約の配列
      }.select {|h| h.size > 0}.first  # 空ではない、一番優先度の高い階層

      if h != nil && h.size == 1
        c = h.pop # hに含まれる唯一の制約
        if c[0] == :ne
          if c[1] == var
            value = c[2] # [:ne 変数var 値value]
          elsif c[2] == var
            value = c[1] # [:ne 値value 変数var]
          else
            # error
          end
          if String === value && readings.select {|x| x.vars == [var] && x.reading == [value]}.size > 0 && readings.select {|x| x.vars == [var]}.size > 1
            # 値は文字 && [変数 制約を充足しない値]がreadingsに含まれている && [変数 その他の値]もreadingsに含まれている。
            # => [変数 制約を充足しない値]を削除する。
            result_readings.delete_if {|x| x.vars == [var] && x.reading == [value]}
          end
        elsif c[0] == :eq
          if c[1] == var
            value = c[2] # [:eq 変数var 値value]
          elsif c[2] == var
            value = c[1] # [:eq 値value 変数var]
          else
            # error
          end
          if String === value && readings.select {|x| x.vars == [var] && x.reading != [value]}.size > 0 && readings.select {|x| x.vars == [var]}.size > 1
            # 値は文字 && [変数 制約を充足しない値]がreadingsに含まれている && [変数 その他の値]もreadingsに含まれている。
            # => [変数 制約を充足しない値]を削除する。
            result_readings.delete_if {|x| x.vars == [var] && x.reading != [value]}
          end
        end
      end
    }
    return result_readings
  end

end
