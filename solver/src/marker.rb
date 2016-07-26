# -*- coding: utf-8 -*-
require_relative './rs_h.rb'
require 'set'

#解を採点するクラス
#CSPの制約グラフで分岐中に分岐がある場合には対応していない
#配点を変更する場合はmark()のpoint+=の部分とmax_point()を変更
class Marker
  #@param [Array<Array<Array<Symbol>,Array<String>>>] value 正しい解(読み)
  attr_writer :right_answer
  
  #コンストラクタ
  #@param [RS::CSP::ConstraintSatisfactionProblem] csp 採点する解のCSP
  def _initialize(csp)
    @csp = csp
    @var_graph = [] #Array<Array<Array<Symbol>>>
    #convert graph
    #制約グラフ
    #1->3->4->   5   ->    8    ->11
    #2->        ->6->7->9->10->
    #を変換 => [[[1],[2]],[[3]],[[4]],[[5],[6,7]],[[8],[9,10]],[[11]]]
    st = csp.heads.collect{|x| [x]}
    until st.empty?
      branch_count = st.size
      tmp_nexts = Set.new
      elements = Set.new
      until st.empty?
        path = st.pop
        dec = csp.decendent_vars_of(path[-1])
        if dec.empty?
          elements.add(path)
        end
        dec.each{|node|
          tmp_path = path.dup
          if csp.ascendent_vars_of(node).size==branch_count
            elements.add(path)
            tmp_nexts.add([node])
          else
            tmp_path.push(node)
            st.push(tmp_path)
          end
        }
      end
      @var_graph.push(elements.to_a)
      st = tmp_nexts.to_a
    end
  end
  
  #コンストラクタ
  #@param [RS::CSP::ConstraintSatisfactionProblem] csp 採点する解のCSP
  def initialize(csp)
    @csp = csp
    @var_graph = [] #Array<Array<Array<Symbol>>>
    #convert graph
    #制約グラフ
    #1->3->4->   5   ->    8    ->11
    #2->        ->6->7->9->10->
    #を変換 => [[[1],[2]],[[3]],[[4]],[[5],[6,7]],[[8],[9,10]],[[11]]]
    var = csp.add_dummy
    while (des = csp.descendent_vars_of(var)) != []
        if des.length == 1
            var = des[0]
            @var_graph.push([[var]])
        else
            junction = csp.search_junction(var)
            @var_graph.push(csp.all_path(var, junction))
            var = csp.ascendent_vars_of(junction)[0]
        end
    end
    @var_graph.pop
  end

  
  #解を採点する
  #@param [Array<Array<Array<Symbol>,Array<String>>>] ans 採点する解
  #@param [Array<Array<Array<Symbol>,Array<String>>>] right_ans 正しい解
  #@return [Float] 点数
  def mark(ans,right_ans=@right_answer)
    answer = normalize(ans)
    right_answer = normalize(right_ans)
    point = 0.0
    right_i = 0
    ans_i = 0
    @var_graph.each{|vars|
      right_len = vars.assoc(right_answer[right_i][0]).length
      ans_len = vars.assoc(answer[ans_i][0]).length
      if right_len == ans_len
        min_len = vars.min{|a,b| a.length<=>b.length}.length.to_f
        right_len.times{|i|
          #if @csp.odoriji?(right_answer[right_i+i][0]) or @csp.odoriji?(answer[ans_i+i][0])
          #  if @csp.odoriji?(right_answer[right_i+i][0]) and @csp.odoriji?(answer[ans_i+i][0])
          #    踊り字の場合は読みではなく両方踊り字かどうかをみる
          #    point += min_len/right_len
          #  end
          #els
          if answer[ans_i+i][1] == right_answer[right_i+i][1]
            #point += min_len/right_len #配点可変
            point += 1.0 #配点固定
          end
        }
      end
      right_i += right_len
      ans_i += ans_len
    }
    return point
  end
  
  #最大得点
  #@return [Integer] 最大得点
  def max_point()
    #return @var_graph.size #配点可変
    return str_length(@right_answer) #配点固定
  end
  
  #解answerの文字列としての長さ
  #@param [Array<Array<Array<Symbol>,Array<String>>>] answer 解
  #@return [Integer] 解answerの文字列としての長さ
  def str_length(answer)
    sum=0
    answer.each{|x|
      sum += x[0].size
    }
    return sum
  end
  
  #文字列を読みの割り当て(解)に変換する
  #@param [String] str 文字列
  #@return [Array<Array<Array<Symbol>,Array<String>>>] 読みの割り当て(解)
  #@example
  #  制約グラフが(:_0 -> :_1 -> :_2),(:_0=>{"あ","お"},:_1=>{"い","し"},:_2=>{"う","つ"})のとき
  #  string_to_assignment("あいう") #=> [[[:_0],["あ"]],[[:_1],["い"]],[[:_2],["う"]]]
  def string_to_assignment(str)
    vars = []
    str_i = 0
    @var_graph.each{|x|
      x.each{|sub_vars|
        if assign?(sub_vars,str.slice(str_i,sub_vars.length))
          vars.concat(sub_vars)
          str_i += sub_vars.length
          break
        end
      }
    }
    ret = []
    vars.each_index{|i|
      ret.push([[vars[i]],[str[i]]])
    }
    return ret
  end
  private
  #解(読みの割り当て)を1つの変数と読みの組みを要素とする配列に正規化する
  #@param [Array<Array<Array<Symbol>,Array<String>>>] answer 解
  #@return [Array<Array<Symbol,String>>] 正規化した解
  #@example
  #  [[[:_1, :_2, :_3], ["あ", "い", "う"]], [[:_4], ["え"]], [[:_5, :_6], ["お", "か"]]] =>
  #  [[:_1, "あ"], [:_2, "い"], [:_3, "う"], [:_4, "え"], [:_5, "お"], [:_6, "か"]]
  def normalize(answer)
    ret = []
    answer.each{|x|
      x[0].each_index{|i|
        ret.push([x[0][i],x[1][i]])
      }
    }
    return ret.sort{|a,b| a[0].to_s.to_i<=>b[0].to_s.to_i}
  end
  
  #変数列varsの各変数に文字列strの各文字を割り当てられるか?
  #@param [Array<Symbol>] vars 変数列
  #@param [String] str 文字列
  #@return [true,false] varsにstrを割り当てられればtrue、そうでなければfalse
  def assign?(vars,str)
    vars.each_index{|i|
      if not @csp.domains[vars[i]].include?(str[i])
        return false
      end
    }
    return true
  end
end

