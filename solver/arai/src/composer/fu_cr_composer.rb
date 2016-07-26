# -*- coding: utf-8 -*-
require 'set'
require 'rubygems'
require 'csp/normalizer'
#$KCODE="u"
#coding:utf-8

#
# なるべくRS::UNREADABLE_CHAR (不可読文字)を含まない読みを合成する。
#
class RS::Composer::FewerUnreadablesCRComposer < RS::Composer::CompleteReadingComposerBase

  public
  # コンストラクタ
  # @param [CSP::ConstraintSatisfactionProblem] csp 制約充足問題
  # @param [Array<RS::CSP::ReadingAssignment>] readings 読みの割り当て結果
  def initialize(csp, readings)
    @csp = csp
    @head_groups = csp.head_groups
    @readings = readings
    @min_unreadables = csp.vars.size
    @max_min_unreadables = csp.vars.size
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
  end

  private
  # 不可読文字数を数える。
  # @param [Array<RS::CSP::ReadingAssignment>] readings 読みの割り当て結果
  # @todo count_unreadablesと類似した処理があるので、それらをまとめる。
  def count_unreadables(readings)
    return ((readings.collect {|x| x.reading}).flatten.select {|x| x == RS::UNREADABLE_CHAR}).size
  end

  private
  # 読みを合成する。{#compose}から呼ばれる。
  # @param [Array<Symbol>] heads 読み始める変数の列
  # @param [Array<RS::CSP::ReadingAssignment>] assigned 探索中に選択した読みの割り当て
  # @note 割り当て結果は @result に記録される。
  def _compose(heads, assigned)
    @count_node += 1
#    print "_compse:#{@count_node}\r"
    heads.each { |h|
#      r = (@readings.find_all { |r| h == r[0][0] })
      if @starts_with[h]
        r = @starts_with[h]
      else
        r = []
      end
#      r.each { |currentReading|
      (r.sort {|a,b| @unreadables[a] <=> @unreadables[b]}).each { |currentReading|
        cur = count_unreadables(assigned + [currentReading])
        if cur > @min_unreadables
          next
        end
        if @csp.tails.include?(currentReading.vars.last)
          if cur < @min_unreadables
            @min_unreadables = cur
            @result.clear
          end
          @result.add(assigned + [currentReading])
        else
          nextHeads = @csp.decendent_vars_of(currentReading.vars.last)
          _compose(nextHeads, assigned + [currentReading])
        end
      }
    }
  end

  public
  # 読みを合成する。
  # @param [Array<Symbol>] heads 読みを開始する変数名の列
  # @return [Array(Set<Array<RS::CSP::ReadingAssignment>)] 読みの割り当て結果の集合の配列。配列の要素数は1。
  def compose_from(heads)
    @result = Set.new
    @min_unreadables = @max_min_unreadables
    _compose(heads, [])
    return [@result]
  end

  public
  # 連結した制約グラフ毎に、読みを合成する。
  # @return [Array<Set<Array<RS::CSP::ReadingAssignment>>>] 読みの割り当て結果の集合の配列。配列の要素数は、連結した読みの割り当てグラフの個数。
  def compose
    @count_node = 0
    result = []
    @head_groups.map {|heads|
      @result = Set.new
      @min_unreadables = @max_min_unreadables
      _compose(heads, [])
      result.push(@result)
    }
    return result
  end
end
