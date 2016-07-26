# -*- coding: utf-8 -*-
require 'csp/constraint_satisfaction_problem'
require 'csp/satisfaction'

#$KCODE="u"
#coding:utf-8

#
# 制約充足問題を視覚化するクラス
#
# @see http://www.graphviz.org/
# @see http://www.graphviz.org/doc/info/lang.html
class RS::CSP::CSPToDOT

  public
  # コンストラクタ
  def initialize
    @number_generator = 0
  end

  private
  # idに使う次の数を生成する。
  # @return [Integer] 0以上の整数
  def next_number
    @number_generator += 1
    return @number_generator
  end

  public
  # 制約充足問題をGraphvizのDOT言語による記述へ変換する。
  # @param [RS::CSP::ConstraintSatisfactionProblem] csp 制約充足問題
  # @return [String] DOT言語による記述
  def translate(csp)
    result = "digraph dag {\n"
    result += "graph [dpi=150, rankdir = LR];\n"

    # variables
    #csp.head_groups.each {|heads|
    #  result += "  subgraph clusterHeads {\n"
    #  result += "    color=white\n"
    #  heads.each {|k|
    #    v = csp.domains[k]
    #    number = next_number
    #    node = "node#{number}"
    #    @var2node[k] = node
    #    result += "#{node} [shape=Mrecord, label=\"#{k}|#{v.join(',')}\"];\n"
    #  }
    #  result += "  }"
    #}

    # variables
    var_to_node = {}
    csp.vars.each {|v|
      if var_to_node[v] == nil
        number = next_number
        node = "node#{number}"
        var_to_node[v] = node
      else
        node = var_to_node[v]
      end
      d = csp.domains[v]
      result += "#{node} [shape=Mrecord, label=\"#{v}|#{d.join(',')}\", group=1];\n"
    }

    # connectivity
    csp.connectivity.each {|e|
      result += "#{var_to_node[e[0]]} -> #{var_to_node[e[1]]};\n"
    }

    # constraints
    0.upto(csp.constraints.length-1) { |s|
      csp.constraints[s].each { |e|
        # 変数 != RS::UNREADABLE_CHAR は省略
        if e[0] == :ne && e[2] == RS::UNREADABLE_CHAR
          next
        end

        # "強度|制約式" というノードを作る
        con = RS::CSP::Evaluator::Constraint.new(s, e)
        number = next_number
        node = "node#{number}"
        label = "#{con.strength}|#{con.expression.inspect}"
        label=label.gsub(/\"/, '\"')
        result += "#{node} [shape=record, label=\"{#{label}}\", group=2];\n"

        con.collect_vars.uniq.each { |v|
          result += "#{node} -> #{var_to_node[v]} [dir=none];\n"
        }
      }
    }
    result += "}\n"

    return result
  end
end
