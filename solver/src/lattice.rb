# -*- coding: utf-8 -*-
require_relative './rs_h.rb'
require_relative './dictionary.rb'
require_relative './double_array.rb'
require_relative './connection_matrix.rb'
require 'set'
require 'depq.rb'

#コスト付き読みの割り当てグラフを表すクラス
class Lattice
  #文頭ノードの単語情報
  INITIAL  = "initial,0,0,0,文頭"
  #文末ノードの単語情報
  TERMINAL = "terminal,0,0,0,文末"
  #未知語の単語情報
  UNKNOWN  = ",0,0,40000,未知語"
  #途中から始まる単語の単語情報
  HALFWAY_BEGIN = ",0,0,40000,途中開始"
  #途中で終わる単語の単語情報
  HALFWAY_END = ",0,0,40000,途中終了"
  
  #コスト付き読みの割り当てグラフを構築する
  #@param [RS::CSP::ConstraintSatisfactionProblem] csp 翻刻制約充足問題
  #@param [DoubleArray] double_array DoubleArray
  #@param [DoubleArray] double_array_reverse 逆引き用DoubleArray
  #@param [ConnectionMatrix] matrix 連接コスト行列
  #@return [void]
  def build(csp,double_array,double_array_reverse,matrix)
    @csp = csp
    @nodes = []
    @nodes.push(Node.new(INITIAL,[:none]))
    @nodei_having_athead = Hash.new #value:変数v(key)を先頭に持つノードのインデックスの配列
    @nodei_having_attail = Hash.new #value:変数v(key)を末尾に持つノードのインデックスの配列
    csp.vars.each do |var|
      domain = csp.domains[var]
      domain.push("!") if not domain.include?("!")
      results = double_array.search_csp_graph(csp,var)
      results.each do |r|
        words = r[0].split(";")
        vars = r[1]
        ranks = r[2]
        str = words.shift
        ranks = ranks.zip(vars).map{|rank, var| csp.odoriji?(var) ? csp.odoriji[var][1] : rank}
        if words.empty?
          words=[HALFWAY_END[1..-1]]
        end
        words.each do |w|
          node = Node.new(str+","+w,vars)
          node.correct_cost(ranks)
          @nodes.push(node)
        end
      end
    end
    csp.vars_reached_from(csp.heads,double_array_reverse.max_length).each do |var|
      results = double_array_reverse.search_csp_graph(csp,var,true)
      results.each do |r|
        words = r[0].split(";")
        vars = r[1].reverse
        ranks = r[2].reverse
        str = words.shift.reverse
        ranks = vars.zip(ranks).map{|var, rank| csp.odoriji?(var) ? csp.odoriji[var][1] : rank}
        if words.empty?
          words=[HALFWAY_BEGIN[1..-1]]
          words.each do |w|
            node = Node.new(str+","+w,vars)
            node.correct_cost(ranks)
            @nodes.push(node)
          end
        end
      end
    end
    @nodes.push(Node.new(TERMINAL,[:none]))
    #必須制約を満たさないノードを削除
    #p @nodes.size
    constraints = @csp.constraints[0].map{|c| RS::CSP::Evaluator::Constraint.new(0, c)}
    @nodes.reject! do |node|
      assignment = node.to_assignment
      assignment.init_pos
      valuation = assignment.to_valuation
      constraints.select{|c| c.evaluable2?(Set.new(node.vars))}.any?{|c| not c.eval(valuation)}
    end
    #p @nodes.size
    
    @nodes.each_with_index do |node, i|
      add_node_index(@nodei_having_athead, node.vars[0], i)
      add_node_index(@nodei_having_attail, node.vars[-1], i)
    end
    connect(matrix)
  end
  
  #読みの割り当てグラフからコスト付き読みの割り当てグラフを構築する
  #@param [RS::CSP::ConstraintSatisfactionProblem] csp 翻刻制約充足問題
  #@param [Array<Array<Array<Symbol>,Array<String>>>] readings 読みの割り当てグラフのノード
  #@param [Dictionary] dictionary 辞書
  #@param [ConnectionMatrix] matrix 連接コスト行列
  #@return [void]
  def build_from_reading(csp,readings,dictionary,matrix)
    @csp = csp
    @nodes = []
    @nodes.push(Node.new(INITIAL,[:none]))
    @nodei_having_athead = Hash.new #value:変数v(key)を先頭に持つノードのインデックスの配列
    @nodei_having_attail = Hash.new #value:変数v(key)を末尾に持つノードのインデックスの配列
    readings.each{|reading|
      head = reading[0][0]
      tail = reading[0][-1]
      word = reading[1].join
      #単語の途中で始まる場合
      position = reading[2]
      phead = position[0].values.first
      ptail = position[-1].values.first
      if not ( (phead==1 and ptail==4) or phead==5 or phead==8 )
        words = [word+UNKNOWN]
      else
        words = dictionary.search(word)
        if words.empty?
          words=[word+UNKNOWN]
        end
      end
      words.each{|w|
        add_node_index(@nodei_having_athead,head,@nodes.size)
        add_node_index(@nodei_having_attail,tail,@nodes.size)
        @nodes.push(Node.new(w,reading[0]))
      }
    }
    @nodes.push(Node.new(TERMINAL,[:none]))
    connect(matrix)
  end
  
  private
  #作成したノードを接続する
  #@param [ConnectionMatrix] matrix 連接コスト行列
  #@return [void]
  def connect(matrix)
    @csp.heads.each{|v| @nodes[0].add_childs(@nodei_having_athead[v])}
    for i in 1..@nodes.size-2
      @csp.ascendent_vars_of(@nodes[i].vars[0]).each do |v|
        if @nodei_having_attail[v]!=nil
          @nodes[i].add_parents(@nodei_having_attail[v])
        end
      end
      
      @csp.decendent_vars_of(@nodes[i].vars[-1]).each do |v|
        if @nodei_having_athead[v]!=nil
          @nodes[i].add_childs(@nodei_having_athead[v])
        end
      end
    end
    @csp.tails.each{|v| @nodes[-1].add_parents(@nodei_having_attail[v])}
    
    @nodes[0].childs.each{|i| @nodes[i].add_parents([0])}
    @nodes[-1].parents.each{|i| @nodes[i].add_childs([@nodes.size-1])}
    #ここが遅い
    #上流と下流のときで同じ辺に対してmatrix.cost()を呼んでいる
    #Nodeの辺の持ち方を変える
    @nodes.each do |node|
      costs = node.connection_costs
      id = node.right_id
      node.childs.each{|i| costs.push(matrix.cost(id,@nodes[i].left_id))}
      
      costs = node.connection_costs_back
      id = node.left_id
      node.parents.each{|i| costs.push(matrix.cost(@nodes[i].right_id,id))}
    end
  end
  
  public
  #文頭ノードから各ノードまでの最小コストを計算する
  #@return [void]
  def calc_min_cost
    order = tsort
    @nodes[0].min_cost = 0
    @nodes[0].childs.each_with_index do |j,c|
        cost = 0 + @nodes[0].connection_costs[c] + @nodes[j].cost
        if @nodes[j].min_cost < 0
          @nodes[j].min_cost = cost
          @nodes[j].min_cost_parent = 0
        end
    end
    order.each do |var|
      @nodei_having_athead[var].each do |i|
        @nodes[i].childs.each_with_index do |j,c|
          cost = @nodes[i].min_cost + @nodes[i].connection_costs[c] + @nodes[j].cost
          if @nodes[j].min_cost < 0 or @nodes[j].min_cost > cost
            @nodes[j].min_cost = cost
            @nodes[j].min_cost_parent = i
          end
        end
      end
    end
  end
  
  #N-best探索をする
  #@param [Integer] n 求める解の個数
  #@return [Array<Array<Array<Lattice::Node>,Integer>>] 上位n個の解とその解の総コスト
  def nbest_search(n)
    ret=[]
    q = Depq.new
    q.insert([-1,nil],@nodes[-1].min_cost)
    until q.empty? or n == ret.size
      x , fx = q.delete_min_priority
      i = x[0]
      if i == 0
        path = [@nodes[0]]
        next_ele = x
        while next_ele = next_ele[1]
          path.push(@nodes[next_ele[0]])
        end
        ret.push([path,fx])
      end
      @nodes[i].parents.each_with_index{|j,c|
        gx = fx - @nodes[i].min_cost + @nodes[i].cost
        fy = gx + @nodes[j].min_cost + @nodes[i].connection_costs_back[c]
        q.insert([j,x],fy)
      }
    end
    return ret
  end
  
  #ノードの数
  #@return [Integer] ノードの数
  def node_count
    @nodes.size
  end
   
  #DOT言語の記述に変換する
  #@return [Stirng]  変換した文字列
  def to_dot
    ret = []
    ret.push('digraph lattice {')
    ret.push('  graph [dpi=150, rankdir = LR];')
    @nodes.each_with_index{|node,i|
      ret.push("  n#{i} #{node.to_dot}")
    }
    @nodes.each_with_index{|node,i|
      node.childs.each_with_index{|num,j|
        if @nodes[num].min_cost_parent==i
          #ret.push("  n#{i} -> n#{num} [label = \"#{node.connection_costs[j]}\", color = red]")
          ret.push("  n#{i} -> n#{num} [label = \"#{node.connection_costs[j]}\"]")
        else
          ret.push("  n#{i} -> n#{num} [label = \"#{node.connection_costs[j]}\"]")
        end
      }
    }
    ret.push('}')
    return ret.join("\n")
  end
  
  #パスをDOT言語の記述に変換する
  #@param [Array<Lattice::Node>] path 変換するパス
  #@return [Stirng]  変換した文字列
  def path_to_dot(path)
    ret = []
    ret.push('digraph lattice {')
    ret.push('  graph [dpi=150, rankdir = LR];')
    path.each_with_index{|node,i|
      ret.push("  n#{i} #{node.to_dot}")
    }
    path.each_with_index{|node,i|
      node.childs.each_with_index{|num,j|
        if @nodes[num]==path[i+1]
          ret.push("  n#{i} -> n#{i+1} [label = \"#{node.connection_costs[j]}\"]")
        end
      }
    }
    ret.push('}')
    return ret.join("\n")
  end
  
  private
  #ハッシュにノードのインデックスを追加する
  #@param [Hash{Symbol=>Array<Integer>}] nodei_hash
  #@param [Symbol] var
  #@param [Integer] nodei
  #@return [void]
  def add_node_index(nodei_hash,var,nodei)
    if nodei_hash[var]==nil
      nodei_hash[var]=[]
    end
    nodei_hash[var].push(nodei)
  end
  
  #制約グラフの変数をトポロジカルソートする
  #@return [Array<Symbol>] トポロジカルソートした変数の配列
  def tsort
    visited = Hash.new(false) 
    result=[]
    @csp.tails.each{|v|
      visit(v,visited,result)
    }
    return result
  end
  
  #{#tsort}メソッドから呼ばれる。制約グラフを再帰的に探索する。
  #@param [Symbol] n 現在訪問している変数
  #@param [Hash{Symbol=>true,false}] visited 変数(key)が訪問済みかどうか
  #@param [Array<Symbol>] result 結果を格納する配列
  #@return [void]
  def visit(n,visited,result)
    if not visited[n]
      visited[n]=true
      @csp.ascendent_vars_of(n).each{|v| visit(v,visited,result)}
      result.push(n)
    end
  end
end

#コスト付き読みの割り当てグラフのノードを表すクラス
class Lattice::Node
  #@return [String] 単語 
  attr_reader :word
  #@return [Integer] 左文脈ID
  attr_reader :left_id
  #@return [Integer] 右文脈ID
  attr_reader :right_id
  #@return [Integer] 生起コスト
  attr_reader :cost
  #@return [String] 単語の種類(品詞など)
  attr_reader :kind
  #@return [Array<Symbol>] 変数列
  attr_reader :vars
  #@return [Array<Integer>] 上流ノードのインデックスの配列
  attr_reader :parents
  #@return [Array<Integer>] 下流ノードのインデックスの配列
  attr_reader :childs
  #@return [Array<Integer>] 下流ノードへの連接コスト
  attr_reader :connection_costs
  #@return [Array<Integer>] 上流ノードへの連接コスト
  attr_reader :connection_costs_back
  #@param [Integer] value 文頭ノードから自身のノードまでの最小コスト
  #@return [Integer] 文頭ノードから自身のノードまでの最小コスト
  attr_accessor :min_cost
  #@param [Integer] value 最小コストとなるパスの上流ノードのインデックス
  #@return [Integer] 最小コストとなるパスの上流ノードのインデックス
  attr_accessor :min_cost_parent
  
  #コンストラクタ
  #@param [Stirng] word 単語情報
  #@param [Array<Symbol>] vars 変数列
  def initialize(word,vars)
    splitted = word.chomp.split(",")
    @word = splitted[0]
    @left_id = splitted[1].to_i
    @right_id = splitted[2].to_i
    @cost = splitted[3].to_i
    @kind = splitted[4]
    @vars = vars
    @parents = []
    @childs = []
    @connection_costs = []
    @connection_costs_back = []
    @min_cost = -1
    @min_cost_parent = -1
  end
  
  #文末ノードから自身のノードまでの最小コスト
  #@return [Integer] 文末ノードから自身のノードまでの最小コスト
  def g
    @f - @min_cost + @cost
  end
  
  #下流ノードを追加する
  #@param [Array<Integer>] nodei 追加するノードのインデックスの配列
  #@return [Array<Integer>] 下流ノードのインデックスの配列
  def add_childs(nodei)
    @childs.concat(nodei)
  end
  
  #上流ノードを追加する
  #@param [Array<Integer>] nodei 追加するノードのインデックスの配列
  #@return [Array<Integer>] 上流ノードのインデックスの配列
  def add_parents(nodei)
    @parents.concat(nodei)
  end
  
  #生起コストを各文字の画像認識結果の順位を元に補正する
  #@param [Array<Integer>] ranks 順位
  #@return [Integer] 補正後の生起コスト
  def correct_cost(ranks)
    sum = ranks.inject(0,&:+)
    a = 0.25
    @cost += (@cost.abs * (sum*a)).to_i
  end
  
  #同じノードかどうか比較する
  #
  #単語、右文脈ID、左文脈ID、生起コストが同じなら同じノードとする
  #
  #@param [Lattice::Node] other 比較対象
  #@return [true,false] 同じノードならtrue、そうでなければfalse
  def ==(other)
    @word==other.word and @left_id==other.left_id and @right_id==other.right_id and @cost==other.cost
  end
  
  #変数列と単語からなる文字列に変換する
  #@return [String] 変換した文字列
  def inspect
    [@vars,@word.split(//)].inspect
  end
  
  #DOT言語の記述に変換する
  #@return [Stirng] 変換した文字列
  def to_dot
    "[shape=Mrecord,label=\"#{@vars.join(",")}|#{@word}|#{@kind}|#{@cost}(#{@min_cost})\"]"
  end
  
  #ReadingAssignmentクラスに変換する
  #@return [RS::CSP::ReadingAssignment] 変換したReadingAssignment
  def to_assignment
    if @kind=="途中開始"
      return RS::CSP::ReadingAssignment.new(@vars,'#'+@word, 1)
    elsif @kind=="途中終了"
      return RS::CSP::ReadingAssignment.new(@vars,@word+'#', 0)
    else
      return RS::CSP::ReadingAssignment.new(@vars,@word, 0)
    end
  end
end

