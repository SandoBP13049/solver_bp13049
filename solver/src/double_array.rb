# -*- coding: utf-8 -*-

#DoubleArrayを使用した辞書
#
#参考
#
#{http://nanika.osonae.com/DArray/dary.html}
#
#{http://nanika.osonae.com/DArray/build.html}
#
#{http://linux.thai.net/~thep/datrie/datrie.html}
#
#{http://d.hatena.ne.jp/sile/20090928/1254142950}
#
#{http://d.hatena.ne.jp/sile/20110807/1312731007}
#
#{http://d.hatena.ne.jp/tkng/20061225/1167038986}
class DoubleArray
  #@return [Integer] 単語の最大長
  attr_reader :max_length
  #Terminal Symbol 終端文字
  TS = ";" 
  public
  #コンストラクタ
  def initialize()
    @base = [] #BASE配列。空き要素にはnilが入る。葉には負数が入り、正数の-1が単語情報が格納されている@dicのインデックスとなる。
    @check = [] #CHECK配列。空き要素には次の空き要素のインデックスの負数が入る(次の空き要素への片方向リストになる)
    @code = {TS=>0} #文字に整数を対応付ける
    @dic=[] #単語情報が格納される。
    @max_length=0
  end
  #ソート済み辞書からDoubleArrayを構築
  #
  #辞書のフォーマット
  #単語(;左文脈ID,右文脈ID,生起コスト,品詞)+
  #単語を先頭として";"区切りで単語情報が1つ以上続いている
  #
  #@param [String] filename ソート済み辞書のファイル名
  #@return [void]
  def build(filename)
    @dic.clear
    open(filename){|f|
      while line = f.gets
        if line=="" then next end
        len = line[0,line.index(TS)].length
        @max_length = [@max_length,len].max
        @dic.push(line.chomp)
      end
    }
    @base.clear
    @check.clear
    (@dic.size+1).times{|t| @check.push(-(t+1))}
    @code.clear
    @code[TS]=0
    _build(0,@dic.size-1,0,0)
  end
  
  #{#build}メソッドの本体
  #@param [Integer] begin_i 遷移先(子ノード)となる範囲の開始位置のインデックス
  #@param [Integer] end_i 遷移先(子ノード)となる範囲の終了位置のインデックス
  #@param [Integer] root_i ルートノードのインデックス
  #@param [Integer] depth 現在の深さ
  #@return [void]
  def _build(begin_i,end_i,root_i,depth)
    if begin_i==end_i
      @base[root_i]=-(begin_i+1)
      #p root_i
      return
    end
    #p root_i
    key=[[@dic[begin_i][depth],begin_i]]
    if @code[@dic[begin_i][depth]]==nil
      @code[@dic[begin_i][depth]]=@code.size
    end
    for i in begin_i+1..end_i
      c = @dic[i][depth]
      if c!=key[-1][0]
        key.push([c,i])
        if @code[c]==nil
          @code[c]=@code.size
        end
      end
    end
    
    min_code = @code.size+10
    max_code = 0
    key.each{|k| 
      min_code = @code[k[0]] if @code[k[0]]<min_code
      max_code = @code[k[0]] if @code[k[0]]>max_code
    }
    pre_i = 0
    base_i = -@check[0]-min_code
    until base_i >= 0
      pre_i = base_i+min_code
      base_i = -@check[base_i+min_code]-min_code
    end
    while true
      if @check[base_i+max_code]==nil
        (base_i+max_code-@check.size+3).times{ @check.push(-(@check.size+1))}
      end
      able=true
      key.each{|k|
        if @check[base_i+@code[k[0]]]>=0
          able=false
          break
        end
      }
      if able
        @base[root_i]=base_i
        key.each{|k|
          p_i = pre_i
          i = -@check[p_i]
          until i == base_i+@code[k[0]]
            p_i = i
            i = - @check[i]
          end
          @check[p_i]=@check[i]
          @check[i]=root_i
        }
        break
      end
      pre_i = base_i+min_code
      base_i = -@check[base_i+min_code]-min_code
    end
    
    key.push(["",end_i+1])
    for i in 0..key.size-2
      _build(key[i][1],key[i+1][1]-1,base_i+@code[key[i][0]],depth+1)
    end
  end
  private :_build
  
  #単語を検索する
  #@param [String] word 単語
  #@return [String] 単語情報、見つからなければ"not_found"
  def search_word(word)
    index = 0
    #word+=TS
    begin
      word.each_char{|c|
        next_i = @base[index]+code[c]
        if index != @check[next_i]
          return "not_found0"
        end
        index = next_i
        if @base[index]<0
          res = @dic[(-@base[index])-1]
          #p res
          if res[0,res.index(TS)]==word
            return res
          else
            return "not_found1"
          end
        end
      }
      result = @base[@base[index]]
      if result < 0 and index==@check[@base[index]]
        return @dic[(-result)-1]
      else
        return "not_found2"
      end
    rescue => exc
      return "not_found3"
    end
  end
  
  #varを先頭に持つ単語をcsp上で検索する
  #is_reverseがtrueの場合は単語の途中から始まりvarを末尾に持つ単語をcsp上で検索する
  #@param [RS::CSP::ConstraintSatisfactionProblem] csp 翻刻制約充足問題
  #@param [Symbol] var 変数
  #@param [true,false] is_reverse デフォルトはfalse
  #@return [Array<Array<String,Array<Symbol>>>] varを先頭に持つ単語の単語情報と変数列の組みの配列、is_reverseがtrueの場合は単語の途中から始まりvarを末尾に持つ単語の部分文字列と変数列の組みの配列
  def search_csp_graph(csp,var,is_reverse = false)
    ret=[]
    @is_reverse = is_reverse
    _search_csp_graph(csp,[],"",[],[var],0,ret)
    return ret
  end
  
  private
  #indexからcharで遷移した後のインデックスを返す
  #遷移できなければ-1を返す
  #@param [Integer] index ダブル配列の遷移前インデックス
  #@param [String] char 遷移するラベルの文字
  #@return [Integer] 遷移後のインデックス、遷移できなければ-1
  def next_index(index, char)
    if @code[char] == nil
      return -1
    end
    next_i = @base[index]+@code[char]
    if index != @check[next_i]
      return -1
    end
    return next_i
  end
  
  #{#search_csp_graph}の本体
  #@param [RS::CSP::ConstraintSatisfactionProblem] csp 翻刻制約充足問題
  #@param [Array<Symbol>] var_seq 現在の変数列
  #@param [String] str 現在の文字列
  #@param [String<Integer>] ranks strの各文字の画像認識結果の順位
  #@param [Array<Symbol>] vars 現在探索している変数の集合
  #@param [Integer] index 現在探索しているDoubleArrayのインデックス
  #@param [Array<Array<String,Array<Symbol>>>] ret 結果を格納する配列
  #@return [void]
  def _search_csp_graph(csp,var_seq,str,ranks,vars,index,ret)
    if vars.length > @max_length
      return
    end
    if @base[index]<0
      res = @dic[(-@base[index])-1]
      word = res[0,res.index(TS)]
      next_vars = @is_reverse ? csp.ascendent_vars_of(var_seq[-1]) : csp.descendent_vars_of(var_seq[-1])
      _search_csp_graph_tail(csp,var_seq,word,ranks,next_vars,ret,res)
      return
    end
    if not @is_reverse
      t_index = next_index(index, TS)
      if t_index >= 0
        ret.push([@dic[(-@base[t_index])-1],var_seq,ranks])
      end
    end
    if vars.empty?
      ret.push([str+TS,var_seq,ranks])
    end
    vars.each do |var|
      csp.domains[var].each_with_index do |char, rank|
        next if char == RS::CSP::ConstraintSatisfactionProblem::DUMMY_CHAR
        next_index = next_index(index, char)
        next if next_index < 0
        next_vars = @is_reverse ? csp.ascendent_vars_of(var) : csp.descendent_vars_of(var)
        _search_csp_graph(csp,var_seq+[var],str+char,ranks+[rank],next_vars,next_index,ret)
      end
    end
  end
    
  #DoubleArrayの探索途中に単語が1つに絞られた時、その単語をcsp上で検索する
  #@param [RS::CSP::ConstraintSatisfactionProblem] csp 翻刻制約充足問題
  #@param [Array<Symbol>] var_seq 現在の変数列
  #@param [String] word 単語
  #@param [String<Integer>] ranks wordの各文字の画像認識結果の順位
  #@param [Array<Symbol>] vars 現在探索している変数の集合
  #@param [Array<Array<String,Array<Symbol>>>] ret 結果を格納する配列
  #@param [String] res 単語情報
  #@return [void]
  def _search_csp_graph_tail(csp,var_seq,word,ranks,vars,ret,res)
    if var_seq.length == word.length
      ret.push([res,var_seq,ranks]) #if not @is_reverse
      return
    end
    if vars.empty?
      ret.push([word[0,var_seq.length],var_seq,ranks])
    else
      vars.each do |var|
        rank = csp.domains[var].index(word[var_seq.length])
        if rank != nil
          next_vars = @is_reverse ? csp.ascendent_vars_of(var_seq[-1]) : csp.descendent_vars_of(var_seq[-1])
          _search_csp_graph_tail(csp,var_seq+[var],word,ranks+[rank],next_vars,ret,res)
        end
      end
    end
  end
  
  public
  #構築したDoubleArrayを保存
  #
  #フォーマット
  #配列長n
  #base,check
  #使用文字数m(終端文字は含まない)
  #code
  #単語数w
  #dic
  #単語の最大長l
  #@param [String] filename 保存するファイル名
  #@return [void]
  def save(filename)
    open(filename,"w"){|f|
      f.puts @base.size
      for i in 0..@base.size-1
        f.puts "#{@base[i]},#{@check[i]}"
      end
      @code.delete(TS)
      f.puts @code.size
      @code.each_key{|key|
        f.puts key
      }
      @code[TS] = 0
      f.puts @dic.size
      @dic.each{|w|
        f.puts w
      }
      f.puts @max_length
    }
  end
  
  #保存したDoubleArrayを読み込む
  #@param [String] filename 読み込むファイル名
  #@return [void]
  def load(filename)
    open(filename){|f|
      n = f.gets.to_i
      @base[n-1]=nil
      @check[n-1]=nil
      n.times{|t|
        line = f.gets.chomp.split(",")
        if line.empty?
          @base[t]=nil
          @check[t]=nil
        else
          @base[t]=line[0].to_i
          @check[t]=line[1].to_i
        end
      }
      m = f.gets.to_i
      m.times{
        line = f.gets.chomp
        @code[line] = @code.size
      }
      w = f.gets.to_i
      w.times{
        line = f.gets.chomp
        @dic.push line
      }
      @max_length = f.gets.to_i
    }
  end
  
  #def save_eval(filename)
  #  open(filename,"w"){|f|
  #    f.puts @base.inspect
  #    f.puts @check.inspect
  #    f.puts @code
  #  }
  #end
  #def load_eval(filename)
  #  open(filename){|f|
  #    @base = eval(f.gets)
  #    @check = eval(f.gets)
  #    @code = eval(f.gets)
  #  }
  #end
end
