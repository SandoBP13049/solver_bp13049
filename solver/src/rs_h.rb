# -*- coding:utf-8 -*-
#新井さんのプログラムを使用するためのヘッダー
#また、オープンクラスを用いていくつかメソッドを追加している

require_relative './rs/rs.rb'
module RS::CSP
end
require_relative './rs/constraint_satisfaction_problem.rb'
require_relative './rs/reading_assignment.rb'
require_relative './rs/satisfaction.rb'

class RS::CSP::ConstraintSatisfactionProblem
  DUMMY_CHAR = '_'
  
  #@return [Hash{Symbol=>Array<Symbol, Integer>}] 踊り字の変数と、その踊り字があった位置との対応
  #@example 変数:x1_1が踊り字で、踊り字が変数:x1_0の領域の2番目にあった場合
  #  {:x1_1=>[:x1_0, 2]}
  attr_reader :odoriji
    
  public
  #変数varが踊り字かどうか
  #@param [Symbol] var 変数
  #@return [true,false] varが踊り字であればtrue、そうでなければfalse
  def odoriji?(var)
    if @odoriji != nil
      return @odoriji.include?(var)
    elsif @odoriji_array != nil
      return @odoriji_array.include?(var)
    else
      @odoriji_array = []
      @constraints.each{|x|
        x.each{|c|
          if c.flatten.include?(:U)
            @odoriji_array.push(c[2])
          end
        }
      }
      return @odoriji_array.include?(var)
    end
  end
  
  #踊り字があった位置にダミーの文字を挿入する
  #@return レシーバ自身
  def insert_dummy
    if @odoriji != nil
      @odoriji.each do |k, v|
        var, rank = v
        d = @domains[var]
        d.insert(rank, DUMMY_CHAR) if d != nil
      end
    end
    return self
  end
  
  #{#decendent_vars_of}メソッドのスペルミス修正
  #@param [Symbol] var 変数
  #@return [Array<Symbol>] varの直後の変数の集合
  def descendent_vars_of(var)
    decendent_vars_of(var)
  end
  
  #先頭(開始)ノードと終端ノードを追加する
  #decendent_vars_ofとascendent_vars_ofに影響を与える
  #@return Symbol 先頭ノード
  def add_dummy
    @decendent_vars_of[:init] = @heads
    @heads.each{|v| @ascendent_vars_of[v] = [:init]}
    @ascendent_vars_of[:terminal] = @tails
    @tails.each{|v| @decendent_vars_of[v] = [:terminal]}
    return :init
  end
  
  #varの合流点を探索する
  #@param [Symbol] var 変数
  #@return [Symbol] varの合流点
  def search_junction(var)
    des = descendent_vars_of(var)
    sz = des.size
    visited = {}
    q = des.map{|v| [v,v]}
    until q.empty?
      v,s = q.shift
      vis = visited[v]
      if vis
        if not vis.include?(s)
          vis.push(s) 
        end
        if vis.size == sz
          return v
        end
      else
        visited[v] = [s]
      end
      descendent_vars_of(v).each{|d| q.push([d,s])}
    end
    return nil
  end
  
  #sからtへの全てのパス。sとtは含まれない。
  #@param [Symbol] s 変数
  #@param [Symbol] t 変数
  #@return [Array<Array<Symbol>>] sからtへの全てのパス。sとtは含まれない。
  def all_path(s,t)
    ret = []
    q = [[s]]
    until q.empty?
      path = q.pop
      if path[-1] == t
        ret.push(path[1..-2])
      else
        descendent_vars_of(path[-1]).each{|v| q.push(path.dup.push(v))}
      end
    end
    return ret
  end
  
  #制約グラフにおいて、varsの各変数から下流へつながる距離length-1以下の変数の集合。
  #@param [コレクション<Symbol>] vars 変数の集合。コレクションにはeachメソッドが定義されている必要がある
  #@param [Integer] length 長さ
  #@return [Set<Symbol>] varsから下流へつながる距離length-1以下の変数の集合
  def vars_reached_from(vars,length)
    result = Set.new
    vars.each{|var| _vars_reached_from(var,length,1,result)}
    return result
  end
  private
  #{#vars_reached_from}メソッドの本体
  #全探索なので効率は悪い?
  #@param [Symbol] var 変数
  #@param [Integer] length 長さ
  #@param [Integer] reach 何番目か(1,2,3,...)。再帰呼び出しの終了条件に用いる。
  #@param [Set<Symbol>] result 結果を保持する集合
  #@return [void]
  def _vars_reached_from(var,length,reach,result)
    if reach<=length
      result.add(var)
      decendent_vars_of(var).each{|dvar| _vars_reached_from(dvar,length,reach+1,result)}
    end
  end
end

class RS::CSP::Evaluator::Constraint
    public
    #{#evaluable?}メソッドで集合を新しく作成しないようにしたもの
    #@param [Set<Symbol>] valuation 変数の集合
    #@return [true, false] valuationの下で評価可能ならtrue, そうでなければfalse
    def evaluable2?(valuation)
        return @involved_variables.subset?(valuation)
    end
end

class RS::CSP::Evaluator::LPBSatisfaction
    public
    #読みの列(解)をセットする。
    #解が求まっているときに{#add_reading}メソッドの代わりに使用する。
    #@param [Array<RS::CSP::ReadingAssignment>] readings 読みの列(解)
    #@return [void]
    def set_readings(readings)
        valuation_set = Set.new
        readings.each{|r|
            r.to_valuation.each{|v|
                @valuation.push(v)
                valuation_set.add(v[0])
            }
        }
        tmp_ineval = Set.new
        @evaluable_constraints = Set.new(@evaluable_constraints)
        @inevaluable_constraints.each{|c|
            if c.evaluable2?(valuation_set)
                @evaluable_constraints.add(c)
                @error[c.strength].add(c) if c.eval(@valuation) == false
            else
                tmp_ineval.add(c)
            end
        }
        @inevaluable_constraints = tmp_ineval
    end
end
