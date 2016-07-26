# -*- coding: utf-8 -*-
require 'set'
#$KCODE="u"
#coding:utf-8

#
# 読みの割り当てを短縮する。
#
# 表記
# * 変数列(v_1, ..., v_n)への読み(a_1, ..., a_n)の割り当てを、((v_1, ..., v_n), (a_1, ..., a_n)) で表現することにする。
#
# 処理
#
# 読みの割り当てグラフにおいて、読みの割り当てグラフに変化がなくなるまで、次の処理を繰り返す。
# * ((v_1, ..., v_n), (a_1, ..., a_n))と((v_1), (a_1))が存在するなら、前者の((v_1, ..., v_n), (a_1, ..., a_n))を((v_2, ..., v_n), (a_2, ..., a_n))に置き換える。
# * ((v_1, ..., v_n), (a_1, ..., a_n))と((v_n), (a_n))が存在するなら、前者の((v_1, ..., v_n), (a_1, ..., a_n))を((v_1, ..., v_n-1), (a_1, ..., a_n-1))に置き換える。
#
# 効果
# * 読みの合成器が処理するノード数が減る。
#
# 考慮すべき事項
# * 単語の切れ目を破壊する。
class RS::Rewriter::ReadingAssignmentShortener < RS::Rewriter::RewriterBase
  private
  # 読みの割り当て後の接続関係を求める。
  #
  # @param [CSP::ConstraintSatisfactionProblem] csp 制約充足問題
  # @param [Array<RS::CSP::ReadingAssignment>] readings 読みの割り当て
  # @return [Set<Array<Array<Symbol, String>>>] connectivity ノードの接続関係
  def character_connectivity(csp, readings)
    connectivity = {} # Hash{ Symbol => Symbol }
    # 2文字以上の単語内の接続関係
    readings.select{|x| x.vars.size > 1}.each{|r|
      ra = r.to_valuation
      0.upto(ra.length-2){|i|
        connectivity[ra[i][0]] = Set.new if connectivity[ra[i][0]] == nil
        connectivity[ra[i][0]].add( ra[i+1][0] )
      }
    }
    # 単語単位の接続関係
    readings.each{|r1|
      next_vars = csp.decendent_vars_of(r1.vars.last) # r1に繋がる変数
      next_vars.each{|s|
        # 読みの集合の中で先頭がsの単語
        readings.select{|read| read.vars.first == s}.each{|r2|
          connectivity[r1.to_valuation.last[0]] = Set.new if connectivity[r1.to_valuation.last[0]] == nil
          connectivity[r1.to_valuation.last[0]].add( r2.to_valuation.first[0] )
        }
      }
    }
    return connectivity
  end

  private
  # 読みの割り当て後の接続関係を作る
  # @param [CSP::ConstraintSatisfactionProblem] csp 制約充足問題
  # @param [Array<RS::CSP::ReadingAssignment>] readings 読みの割り当て
  def init_character_connectivity(csp , readings)
    @connectivity = character_connectivity(csp, readings)
  end

  private
  # 読みの割り当て character の直後の、読みの割り当ての集合を返す。
  #
  # @param [Array<Symbol, String>] character 一つの変数とその変数に割り当てられた値
  # @param [CSP::ConstraintSatisfactionProblem] csp 制約充足問題
  # @param [Array<RS::CSP::ReadingAssignment>] readings 読みの割り当て
  # @return [Array<Array<Symbol, String>>] next_characters
  def next_characters(csp, character, readings)
    character_conectivity(csp, readings).select{|c| c[0] == character}.map{|x| x[1]}
  end

  private
  # 読みの割り当て character の直前の、読みの割り当ての集合を返す。
  #
  # @param [Array<Symbol, String>] character 一つの変数とその変数に割り当てられた値
  # @param [CSP::ConstraintSatisfactionProblem] csp 制約充足問題
  # @param [Array<RS::CSP::ReadingAssignment>] readings 読みの割り当て
  # @return [Array<Array<Symbol, String>>] previous_characters
  def previous_characters(csp, character, readings)
    character_conectivity(csp, readings).select{|c| c[1] == character}.map{|x| x[0]}
  end

  private
  # 読みの割り当て character の直後の読みの割り当て sc から見た、直前の読みの割り当ての集合を返す。
  #
  # @param [Array<Symbol, String>] character 一つの変数とその変数に割り当てられた値
  # @param [CSP::ConstraintSatisfactionProblem] csp 制約充足問題
  # @param [Array<RS::CSP::ReadingAssignment>] readings 読みの割り当て
  # @return [Array<Array<Symbol, String>>] next_previous_characters
  def next_previous_characters(csp, character, readings)
    next_previous_characters = Set.new
    sc = next_characters(csp, character, readings)
    sc.each{|c|
      next_previous_characters.add(previous_characters(csp, c, readings) )
    }
    return next_previous_characters.flatten
  end

  private
  # 読みの割り当て character の直前の読みの割り当て pc から見た、直後の読みの割り当ての集合を返す。
  #
  # @param [Array<Symbol, String>] character 一つの変数とその変数に割り当てられた値
  # @param [CSP::ConstraintSatisfactionProblem] csp 制約充足問題
  # @param [Array<RS::CSP::ReadingAssignment>] readings 読みの割り当て
  # @return [Array<Array<Symbol, String>>] previous_next_characters
  def previous_next_characters(csp, character, readings)
    previous_next_characters = Set.new
    pc = previous_characters(csp, character, readings)
    pc.each{|c|
      previous_next_characters.add( next_characters(csp, c, readings) )
    }
    return previous_next_characters.flatten
  end

  private
  # 前方からマージできるか
  # @param [CSP::ConstraintSatisfactionProblem] csp 制約充足問題
  # @param [Array<RS::CSP::ReadingAssignment>] readings 読みの割り当て
  # @param [RS::CSP::ReadingAssignment] r チェック対象の読みの割り当て
  # @return [Boolean] 可能な場合は true、グラフが変化する場合 fales
  def front_merge?(csp, readings, r)
    # r を除去
    new_ra = Set.new(readings.select{|x| !x.eql?(r) })
    tr = r.to_valuation
    tr.shift
    #divide_valuation = tr.shift
    #divide_r = RS::CSP::ReadingAssignment.new([divide_valuation].map {|x| x[0]}, r.word, r.start)
    #divide_r.init_pos
    #new_ra.add(divide_r);
    start = r.start + 1
    # 新しい読みの割り当て
    new_r = RS::CSP::ReadingAssignment.new(tr.map {|x| x[0]}, r.word, start)
    new_r.init_pos
    new_ra.add(new_r)
    connectivity = character_connectivity(csp, new_ra.to_a)

    return connectivity == @connectivity
  end

  private
  # 後方からマージできるか
  # @param [CSP::ConstraintSatisfactionProblem] csp 制約充足問題
  # @param [Array<RS::CSP::ReadingAssignment>] readings 読みの割り当て
  # @param [RS::CSP::ReadingAssignment] r チェック対象の読みの割り当て
  # @return [Boolean] 可能な場合は true、グラフが変化する場合 fales
  def back_merge?(csp, readings, r)
    # r を除去
    new_ra = Set.new(readings.select{|x| !x.eql?(r) })
    tr = r.to_valuation
    tr.pop
    #divide_valuation = tr.pop
    #divide_r = RS::CSP::ReadingAssignment.new([divide_valuation].map {|x| x[0]}, r.word, r.start)
    #divide_r.init_pos
    #new_ra.add(divide_r);
    # 新しい読みの割り当て
    new_r = RS::CSP::ReadingAssignment.new(tr.map {|x| x[0]}, r.word, r.start)
    new_r.init_pos
    new_ra.add(new_r)
    connectivity = character_connectivity(csp, new_ra.to_a)

    return connectivity == @connectivity
  end

  private
  # 配列内の文字列の内, 同じ読みである全ての文字の属性値が同じか判定する.
  # @param [Array<String> , String]
  # @return [true,false] 一つでも異なる属性値を持つ文字があればfalse, 全て同じならtrue.
  def eql_attr?(c_array, c)
    c_array.select{|x| x == c}.each{|target|
      if target.attr != c.attr
        return false
      end
    }
    return true
  end

  private
  # 読みの割り当てを併合する。{#translate} から繰り返し呼ばれる。
  #
  # @param [Array<RS::CSP::ReadingAssignment>] readings 読みの割り当て
  # @return [Array<RS::CSP::ReadingAssignment>] 併合処理後の、読みの割り当て
  def _merge_readings(csp, readings)
    # 変数 -> それに割り当てられている文字の集合
    possible_valuation = {}
    readings.select {|r| r.vars.size == 1}.each {|r|
      if possible_valuation[r.vars.first] == nil
        possible_valuation[r.vars.first] = Set.new
      end
      possible_valuation[r.vars.first].add(r.reading.first)
    }

    # 一文字のみの読みは無条件で結果に含める。
    merged_reading_set = Set.new(readings.select {|r| r.vars.size == 1})

    # 2変数以上を含む読みについて
    readings.select {|r| r.vars.size >= 2}.each {|r|
      tr = r.to_valuation # trは [[:_0, "あ"], [:_1, "い"]] のような [変数名, 文字]を要素とする配列
      tr.select {|x| possible_valuation[x[0]] == nil}.each {|x|  # x[0]は変数名, x[1]はその変数に割り当てる文字
        possible_valuation[x[0]] = Set.new
      }

      start = r.start
      if tr.first != nil && possible_valuation[tr.first[0]].include?(tr.first[1])
        head = tr.shift
        start += 1
      end
      if tr.last != nil && possible_valuation[tr.last[0]].include?(tr.last[1])
        tail = tr.pop
      end
      if tr.size > 0
        ra = RS::CSP::ReadingAssignment.new(tr.map {|x| x[0]}, r.word, start)
        ra.init_pos
        merged_reading_set.add(ra)
      end
    }
    return merged_reading_set.to_a
  end

  private
  # 新しい接続関係ができないように読みの割り当てを併合する。{#translate} から繰り返し呼ばれる。
  def merge_readings_connectivity(csp, readings)
    merged_reading_set = Set.new
    # 単語割り当て後の接続関係を生成
    init_character_connectivity(csp, readings)
    possible_valuation = {} # 変数 -> それに割り当てられている文字の集合. 一文字の単語のみ
    readings.select {|r| r.vars.size == 1}.each {|r|
      if possible_valuation[r.vars.first] == nil
        possible_valuation[r.vars.first] = Set.new
      end
      possible_valuation[r.vars.first].add(r.reading.first)
    }
    # 一文字のみの読みは無条件で結果に含める。
    merged_reading_set = Set.new(readings.select {|r| r.vars.size == 1})
    # 一文字の同じ読みを統一
#    merged_reading_set.each{|r|
#      r_similar = merged_reading_set.select{|x| x.reading.first == r.reading.first && x.vars.first == r.vars.first}
#      if r_similar.size > 1
#        #puts "#{r_similar.inspect}"
#        merged_reading_set.delete(r)
#        r_similar.each{|rs|
#          # 属性値の更新
#          r.reading.first.attr[:position] = rs.reading.first.attr[:position] | r.reading.first.attr[:position]
#          merged_reading_set.delete(rs)
#        }
#        merged_reading_set.add(r)
#      end
#    }
    # 接続関係確認用の集合
    current_reading_set = Set.new(readings.select {|r| r.vars.size > 0})
    # 2変数以上を含む読みについて
    readings.select {|r| r.vars.size >= 2}.each {|r|
      tr = r.to_valuation # trは [[:_0, "あ"], [:_1, "い"]] のような [変数名, 文字]を要素とする配列
      tr.select {|x| possible_valuation[x[0]] == nil}.each {|x|  # x[0]は変数名, x[1]はその変数に割り当てる文字
        possible_valuation[x[0]] = Set.new
      }
      start = r.start
      new_r = r
      # 先頭の文字が一致していた場合
      if tr.first != nil && possible_valuation[tr.first[0]].include?(tr.first[1]) && eql_attr?(possible_valuation[tr.first[0]] , tr.first[1])
        # マージしてもグラフが変化しない場合
        #puts "front => #{front_merge?(csp, current_reading_set.to_a, r)}"
        if front_merge?(csp, current_reading_set.to_a, r)
          head = tr.shift
          start += 1
          new_r = RS::CSP::ReadingAssignment.new(tr.map {|x| x[0]}, r.word, start)
          new_r.init_pos
          #puts "front merge"
          current_reading_set.add(new_r)
          current_reading_set.delete(r)
          #puts "add #{new_r.inspect}"
          #puts "delete #{r.inspect}"
          front = merged_reading_set.select{|x| x.vars.first == head.first && x.reading.first == head.last && x.vars.size == 1}.first
          #puts "front = #{front.inspect}, head = #{head.inspect}"
          #front.reading.first.attr[:position] = front.reading.first.attr[:position] | head.last.attr[:position]
        end
      end
      # 末尾の文字が一致していた場合
      if tr.last != nil && possible_valuation[tr.last[0]].include?(tr.last[1]) && eql_attr?(possible_valuation[tr.last[0]] , tr.last[1])
        # 後方からマージできる場合
        #puts "back => #{back_merge?(csp, current_reading_set.to_a, new_r)}"
        if back_merge?(csp, current_reading_set.to_a, new_r)
          #puts "back merge"
          tail = tr.pop
          #puts "delete #{new_r.inspect}"
          current_reading_set.delete(new_r)

          new_r = RS::CSP::ReadingAssignment.new(tr.map {|x| x[0]}, r.word, start)
          new_r.init_pos
          current_reading_set.add(new_r)
          #puts "add #{new_r.inspect}"

          back = merged_reading_set.select{|x| x.vars.first == tail.first && x.reading.first == tail.last && x.vars.size == 1}.first
          #puts "back = #{back.inspect}, tail = #{tail.inspect}"
          #back.reading.first.attr[:position] = back.reading.first.attr[:position] | tail.last.attr[:position]
        end
      end
      # マージ結果が1以上なら結果に追加
      if tr.size > 0
        merged_reading_set.add(new_r)
      end
    }
    merged_reading_set.to_a
  end

  public
  # 読みの割り当てを併合する.
  #
  # @param [CSP::ConstraintSatisfactionProblem] csp 制約充足問題
  # @param [Array<RS::CSP::ReadingAssignment>] readings 読みの割り当て
  # @return [Array<RS::CSP::ReadingAssignment>] 書き換え結果
  def translate(csp, readings)
    to_be_merged = readings
    while (true)
      #merged = _merge_readings(csp, to_be_merged)
      merged = merge_readings_connectivity(csp, to_be_merged)
      if to_be_merged.size == merged.size
        break
      else
        to_be_merged = merged
      end
    end
    return merged
  end

end
