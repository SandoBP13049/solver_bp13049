# -*- coding: utf-8 -*-

require 'csp/constraint_satisfaction_problem'
require 'csp/satisfaction'

#$KCODE="u"
#coding:utf-8

#
# 読みの割り当てを視覚化するクラス
#
# @see http://www.graphviz.org/
# @see http://www.graphviz.org/doc/info/lang.html
class RS::CSP::ReadingToDOT
  public
  # コンストラクタ
  def initialize
    @number_generator = 0
  end

  public
  # 読みの割り当てをGraphvizのDOT言語による記述へ変換する。
  # @param [RS::CSP::ConstraintSatisfactionProblem] csp 制約充足問題
  # @param [Array<Array(Array<Symbol>, Array<String>)>] readings 読みの割り当て結果  [ 変数列, 仮名の列 ]の列
  # @param [Array<Array(Array<Symbol>, Array<String> , Array<Hash>)>] readings 読みの割り当て結果  [ 変数列, 仮名の列 , 属性列 ]の列
  # @return [String] DOT言語による記述
  def translate(csp, readings)

    # 各読みに名前をつける
    numberGenerator = 0;
    nodeName = Hash.new
    readings.each { |r|
      nodeName[r] = "node#{numberGenerator.to_s}"
      numberGenerator = numberGenerator + 1
    }

    # 変数名から読みノードへの対応
    var2NodeName = Hash.new
    readings.each { |r|
      r[0].each { |v|
        var2NodeName[v] = nodeName[r]
      }
    }

    # 連結グラフごとにグループ化する
    groupGenerator = 0
    groupName = Hash.new
    groups = []
    csp.head_groups.each {|heads|
      # グループの最上流変数を追加する。
      front = []
      (readings.select {|r| heads.include?(r[0][0])}).each {|r|
        front.push(r)
      }

      group = Set.new
      while(front.size > 0)
        f = front.pop
        if group.include?(f) == false
          group.add(f)
          csp.connectivity.select {|cn| f[0].last == cn[0]}.each {|cn|
            readings.select {|r| cn.last == r[0].first}.each {|x|
              front.push(x)
            }
          }
        end
      end

      groups.push(group)
      group.each {|r|
        groupName[r] = groupGenerator
      }
      groupGenerator += 1
    }

    result = []
    # 出力
    result.push("digraph readings {")
    result.push("  graph [dpi=150, rankdir = LR];")

    0.upto(groups.size-1).each {|g|
      result.push("  subgraph g#{g} {")
      #result.push("    color=gray")

      result.push("    subgraph clusterHeads#{g} {")
      result.push("      color=transparent")
      groups[g].select { |r| groups[g].include?(r) && csp.heads.include?(r[0][0]) }.each { |r|
        #result.push("      #{nodeName[r]} [color=red, shape=Mrecord, label=\"#{r[0].join(',')}|#{r[1].join(',')}\", group=#{groupName[r]}];")
        string_attr = []
        r[2].first.keys.each{|key|
          string_attr << [key]
        }
        r[2].each{|h|
          h.each{|key,val|
            string_attr.assoc(key) << val
          }
        }
        attributes = ""
        string_attr.each{|attr|
          key = attr.shift
          attributes += "|{" + key.to_s + "|" + attr.join(',') + "}"
        }
        result.push("      #{nodeName[r]} [color=red, shape=Mrecord, label=\"#{r[0].join(',')}|#{r[1].join(',')}#{attributes}\", group=#{groupName[r]}];")
      }
      result.push("    }")

      result.push("    subgraph clusterTails {")
      #result.push("      color=white")
      result.push("      color=transparent")
      groups[g].select { |r| groups[g].include?(r) && csp.tails.include?(r[0].last) }.each { |r|
        #result.push("      #{nodeName[r]} [color=red, shape=Mrecord, label=\"#{r[0].join(',')}|#{r[1].join(',')}\", group=#{groupName[r]}];")
        string_attr = []
        r[2].first.keys.each{|key|
          string_attr << [key]
        }
        r[2].each{|h|
          h.each{|key,val|
            string_attr.assoc(key) << val
          }
        }
        attributes = ""
        string_attr.each{|attr|
          key = attr.shift
          attributes += "|{" + key.to_s + "|" + attr.join(',') + "}"
        }
        result.push("      #{nodeName[r]} [color=red, shape=Mrecord, label=\"#{r[0].join(',')}|#{r[1].join(',')}#{attributes}\", group=#{groupName[r]}];")
      }
      result.push("    }")

      result.push("    subgraph clusterMiddles {")
      #result.push("      color=white")
      result.push("      color=transparent")
      groups[g].select { |r| groups[g].include?(r) && !csp.heads.include?(r[0][0]) && !csp.tails.include?(r[0].last) }.each { |r|
        #result.push("      #{nodeName[r]} [shape=Mrecord, label=\"#{r[0].join(',')}|#{r[1].join(',')}\", group=#{groupName[r]}];")
        string_attr = []
        r[2].first.keys.each{|key|
          string_attr << [key]
        }
        r[2].each{|h|
          h.each{|key,val|
            string_attr.assoc(key) << val
          }
        }
        attributes = ""
        string_attr.each{|attr|
          key = attr.shift
          attributes += "|{" + key.to_s + "|" + attr.join(',') + "}"
        }
        result.push("      #{nodeName[r]} [shape=Mrecord, label=\"#{r[0].join(',')}|#{r[1].join(',')}#{attributes}\", group=#{groupName[r]}];")
      }
      result.push("    }")
      result.push("  }")
    }

    readings.each { |p|
      nextHeads = csp.connectivity.select {|x| p[0].last == x[0]}.map {|x| x[1]}
      readings.select { |q| nextHeads.include?(q[0][0]) }.each { |r|
        result.push("  #{nodeName[p]}->#{nodeName[r]};")
      }
    }

    # 評価可能な未充足制約だけ描画する
    if false
      satisfaction = RS::CSP::Evaluator::UCBSatisfaction.new(csp.constraints)
      readings.each {|r|
        satisfaction = satisfaction.add_reading(r)
      }
      satisfaction.evaluable_constraints.select { |c| c.eval(satisfaction.valuation) == false}.each {|con|
        conNodeName = "node#{numberGenerator.to_s}"
        numberGenerator = numberGenerator + 1

        label = "#{con.strength}|#{con.expression.inspect}"
        label=label.gsub(/\"/, '\"')
        result.push("  #{conNodeName} [shape=record, label=\"{#{label}}\", color=red, group=2];")

        con.collect_vars.each {|v|
          result.push("  #{conNodeName}->#{var2NodeName[v]} [color=red, dir=none];")
        }
      }
    end
    result.push("}")

    return result.join("\n")
  end
end
