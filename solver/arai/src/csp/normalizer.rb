# -*- coding: utf-8 -*-
require 'set'
require 'tsort'
require 'csp/constraint_satisfaction_problem'
require 'csp/satisfaction'
#$KCODE="u"
#coding:utf-8

#
# 制約充足問題の変数のトポロジカルオーダを求めるクラス
#
class RS::CSP::VariableSorter
  include TSort

  public
  # @param [RS::CSP::ConstraintSatisfactionProblem] csp 制約充足問題
  def initialize(csp)
    @csp = csp
  end

  public
  # TSortモジュールのメソッド。
  # 変数を列挙する。
  def tsort_each_node(&block)
    @csp.vars.each(&block)
  end

  public
  # TSortモジュールのメソッド。
  # ある変数の直下の変数を列挙する。
  def tsort_each_child(node, &block)
    @csp.connectivity.select {|e| e[0] == node}.map {|e| e[1]}.each(&block)
  end
end

#
# おどり字("々", "ゝ")を処理し、制約充足問題を正規化するクラス
#
class RS::CSP::Normalizer
  private
  #
  # 未使用の変数名を生成する。
  # @param [#to_s] prefix 変数名の接頭辞
  # @param [Hash] csp_hash 制約充足問題のハッシュ表現
  # @return [Symbol] csp_hash内では未使用かつ今までに生成していない、prefixを接頭辞に持つ変数名
  def next_var(prefix, csp_hash)
    generator = 0
    result = prefix.to_s + "_" + generator.to_s
    while (csp_hash[:vars].keys & [result]).size > 0 || (@generated_vars & [result]).size > 0
      generator += 1
      result = prefix.to_s + "_" + generator.to_s
    end
    @generated_vars.push(result)
    return result.to_sym
  end

  private
  #
  # 最上流の変数から最下流の変数に向かう変数のトポロジカルオーダーを求める。
  #
  # @param [RS::CSP::ConstraintSatisfactionProblem] csp 制約充足問題
  # @return [Array<Symbol>] 変数列
  def topological_order(csp)
    return RS::CSP::VariableSorter.new(csp).tsort.reverse
  end

  private
  #
  # 制約充足問題の最上流変数を求める。
  # @param [Hash] csp_hash 制約充足問題のハッシュ表現
  # @return [Array<Symbol>] 最上流の変数の列
  # @note {RS::CSP::ConstraintSatisfactionProblem#heads}と機能が重複している。
  def heads(csp_hash)
    heads = csp_hash[:vars].keys
    csp_hash[:connectivity].each {|e|
      heads = heads - [e[1]]
    }
    return heads
  end

  private
  #
  # 一つ上流の変数を求める。
  #
  # @param [Hash] csp_hash 制約充足問題のハッシュ表現
  # @param [Symbol] var 変数
  # @return [Array<Symbol>] 変数varのすぐ上流の変数の列
  #
  # @note {RS::CSP::ConstraintSatisfactionProblem#ascendent_vars_of}と機能が重複している。
  #
  def ascendent_vars_of(csp_hash, var)
    return (csp_hash[:connectivity].select {|e| e[1] == var}).map {|e| e[0]}
  end

  private
  #
  # 一つの制約c中の変数fromをtoに置き換える。
  # {#replace_vars}から呼ばれる。
  #
  # @param [Array, Symbol] c 制約式
  # @param [Symbol] from 置換前の変数名
  # @param [Symbol] to 置換後の変数名
  # @return [Array, Symbol] 変数fromをtoに置き換た制約式
  def replace_var(c, from, to)
    if Array === c
      c.map {|e| replace_var(e, from, to)}
    elsif from == c
      to
    else
      c
    end
  end

  private
  #
  # 制約階層中の変数をsubstitutionにしたがって置換する。
  #
  # @param [Array<Array<Array>>] constraints 制約階層
  # @param [Hash{Symbol=>Array<String>}] substitution  代入
  # @example 利用例
  #  constraints = [  # 2つの階層からなる制約階層
  #                 [[:eq, :x1, "あ"], [:eq, :x2, "い"]],
  #                 [[:eq, :x1, :x2]]
  #                ]
  #  substitution = { # 代入
  #                  :x1=>[:y1, :y2],  # 変数:x1を:y1か:y2のいずれかに置き換える。
  #                  :x2=>[:z1, :z2, :z3]  # 変数:xxを:z1か:z2か:z3のいずれかに置き換える。
  #                 }
  #  replace_vars(constraints, substitution)
  #  #=> [
  #  #    [ [:eq, :y1, "あ"], [:eq, :y2, "あ"], [:eq, :z1, "い"], [:eq, :z2, "い"], [:eq, :z3, "い"] ],
  #  #    [ [:eq, :y1, :z1], [:eq, :y1, :z2], [:eq, :y1, :z3], [:eq, :y2, :z1], [:eq, :y2, :z2], [:eq, :y2, :z3] ]
  #  #   ]
  def replace_vars(constraints, substitution)
    substitution.each {|from,tos|
      constraints = constraints.map {|h| # 1つの階層
        nextH = []
        h.each {|c|
          if c.flatten.include?(from)  # cにfromが含まれるなら置換したものをnextHに追加する。
            nextH = nextH + tos.map {|to| replace_var(c, from, to)} # c中のfromをtoに置換した制約
          else
            nextH.push(c) # 置換しない制約
          end
        }
        nextH
      }
    }
    return constraints
  end

  public
  # おどり字を解消し、制約充足問題を正規化する。
  # @param [Hash] csp_hash ハッシュ表現の制約充足問題
  # @return [Hash] 正規化されたハッシュ表現の制約充足問題
  # @todo メソッドが長すぎるので分割する。
  def translate(csp_hash)
    @additional_constraints = []
    @generated_vars = []

    src_csp = RS::CSP::ConstraintSatisfactionProblem.new(csp_hash)
    result_csp_hash = csp_hash.dup
    result_csp = RS::CSP::ConstraintSatisfactionProblem.new(result_csp_hash)

    topological_ordered_vars = topological_order(result_csp)
    to_be_replaced1 = topological_ordered_vars.select {|v| (src_csp.domains[v] & [RS::ODORIJI_1]).size > 0}.uniq

    # 変数置換
    substitution = {}

    result_csp_hash[:odoriji] = {}

    # RS::ODORIJI_1を含む変数の処理
    to_be_replaced1.each {|v|
      substitution[v] = []
      # 変数置換
      v1 = next_var(v, result_csp_hash) # 利用されないかもしれない
      v2 = next_var(v, result_csp_hash) # 必ず利用される
      substitution[v].push(v2)

      d = result_csp_hash[:vars][v]
      d1 = d.select {|e| e != RS::ODORIJI_1}
      result_csp_hash[:vars].delete(v)
      if d1.size > 0
        result_csp_hash[:vars][v1] = d1
        substitution[v].push(v1)
      end

      rank = d.index(RS::ODORIJI_1)
      result_csp_hash[:odoriji][v2] = [v1,rank]

      # 有効辺の置換
      result_csp_hash[:connectivity].select {|e| e[0] == v}.each {|e|
        # v=>e[1] を v1=>e[1] と v2=>e[1]に置き換える。
        result_csp_hash[:connectivity].delete(e)
        if d1.size > 0
          result_csp_hash[:connectivity].push([v1,e[1]])
        end
        result_csp_hash[:connectivity].push([v2,e[1]])
      }
      result_csp_hash[:connectivity].select {|e| e[1] == v}.each {|e|
        # e[0]=>v を e[0]=>v1 と e[0]=>v2に置き換える。
        result_csp_hash[:connectivity].delete(e)
        if d1.size > 0
          result_csp_hash[:connectivity].push([e[0],v1])
        end
        result_csp_hash[:connectivity].push([e[0],v2])
      }

      if (heads(result_csp_hash) & [v2]).size > 0
        d2 = [RS::ANY_CHAR]
      else
        d2 = (ascendent_vars_of(result_csp_hash, v2).map {|av|
                result_csp_hash[:vars][av]}
              ).flatten.uniq.select {|x| x != nil}
      end
      if d2.size == 0
        d2 = [RS::ANY_CHAR]
      end
      result_csp_hash[:vars][v2] = d2

      # vがv1?, v2に置き換わった
      # 制約 p(v) == v if v.domain != [RS::ANY_CHAR]
      if d2 != [RS::ANY_CHAR]
        @additional_constraints.push([:eq, [:U, v2, 1], v2])
      end
    }

    # RS::ODORIJI_2を含む変数の処理
    result_csp = RS::CSP::ConstraintSatisfactionProblem.new(result_csp_hash)
    topological_ordered_vars = topological_order(result_csp)
    to_be_replaced2 = topological_ordered_vars.select {|v| (result_csp_hash[:vars][v] & [RS::ODORIJI_2]).size > 0}.uniq

    to_be_replaced2.each {|v|
      substitution[v] = []
      # 変数置換
      v1 = next_var(v, result_csp_hash) # 利用されないかもしれない
      v2 = next_var(v, result_csp_hash) # 必ず利用される
      v3 = next_var(v, result_csp_hash) # 必ず利用される
      substitution[v].push(v2)
      substitution[v].push(v3)

      d = result_csp_hash[:vars][v]
      d1 = d.select {|e| e != RS::ODORIJI_2}

      result_csp_hash[:vars].delete(v)
      if d1.size > 0
        result_csp_hash[:vars][v1] = d1
        substitution[v].push(v1)
      end

      # 有効辺の置換
      result_csp_hash[:connectivity].select {|e| e[1] == v}.each {|e|
        # e[0]=>v を e[0]=>v1 と e[0]=>v2に置き換える。
        result_csp_hash[:connectivity].delete(e)
        if d1.size > 0
          result_csp_hash[:connectivity].push([e[0],v1])
        end
        result_csp_hash[:connectivity].push([e[0],v2])
      }

      # v2=>v3を追加する。
      result_csp_hash[:connectivity].push([v2,v3])

      result_csp_hash[:connectivity].select {|e| e[0] == v}.each {|e|
        # v=>e[1] を v1=>e[1] と v3=>e[1]に置き換える。
        result_csp_hash[:connectivity].delete(e)
        if d1.size > 0
          result_csp_hash[:connectivity].push([v1,e[1]])
        end
        result_csp_hash[:connectivity].push([v3,e[1]])

      }

      h = heads(result_csp_hash)
      if (h & [v2]).size > 0 || (h & ascendent_vars_of(result_csp_hash, v2)).size > 0
        d2 = [RS::ANY_CHAR]
      else
        d2 = (ascendent_vars_of(result_csp_hash, v2).map {|av|
                ascendent_vars_of(result_csp_hash, av).map {
                  |aav| result_csp_hash[:vars][aav]
                }
              }).flatten.uniq.select {|x| x != nil}
      end
      if d2.size == 0
        d2 = [RS::ANY_CHAR]
      end
      result_csp_hash[:vars][v2] = d2

      if (h & [v3]).size > 0 || (h & ascendent_vars_of(result_csp_hash, v3)).size > 0
        d3 = [RS::ANY_CHAR]
      else
        d3 = (ascendent_vars_of(result_csp_hash, v3).map {|av|
                ascendent_vars_of(result_csp_hash, av).map {
                  |aav| result_csp_hash[:vars][aav]
                }
              }).flatten.uniq.select {|x| x != nil}
      end
      if d3.size == 0
        d3 = [RS::ANY_CHAR]
      end
      result_csp_hash[:vars][v3] = d3

      # vがv1?, v2, v3に置き換わった
      # 制約 p(v2) == v2 if v2.domain != [RS::ANY_CHAR]
      # 制約 p(v3) == v3 if v3.domain != [RS::ANY_CHAR]
      if d2 != [RS::ANY_CHAR]
        @additional_constraints.push([:eq, [:U, v2, 2], v2])
      end
      if d3 != [RS::ANY_CHAR]
        @additional_constraints.push([:eq, [:U, v3, 2], v3])
      end
    }

    # RS::ANY_CHARを含んでいるドメインをRS::ANY_CHARのみにする。
    #puts result_csp_hash[:vars].inspect
    result_csp_hash[:vars].keys.each {|v|
      if (result_csp_hash[:vars][v] & [RS::ANY_CHAR]).size > 0
        result_csp_hash[:vars][v] = [RS::ANY_CHAR]
      end
    }

    # おどり字制約を追加
    result_csp_hash[:constraints][0] = (result_csp_hash[:constraints][0] + @additional_constraints).uniq

    # 変数置換
    result_csp_hash[:constraints] = replace_vars(result_csp_hash[:constraints], substitution)

    # 消えた変数に関する制約を削除する
    vars=result_csp_hash[:vars].keys
    valuation=[vars, [].fill("", 0..vars.length-1)].transpose
    0.upto(result_csp_hash[:constraints].length-1) {|i|
      result_csp_hash[:constraints][i].delete_if {|c|
        !(RS::CSP::Evaluator::Constraint.new(i, c)).evaluable?(valuation)
      }
    }

    return result_csp_hash
  end
end
