# -*- coding: utf-8 -*-

#辞書を保持して単語を検索するクラス
#
#辞書ファイルのフォーマット
#
#単語,左文脈ID,右文脈ID,生起コスト,品詞
#
#DoubleArrayの構築に使用している辞書ファイルのフォーマットには対応していない
class Dictionary
  #コンストラクタ
  #@param [String] filename 辞書ファイルの名前
  def initialize(filename)
    @word_info = []
    open(filename){|f|
      while line = f.gets
        @word_info.push(line)
      end
    }
  end
  
  #単語を検索する
  #@param [Stirng] word 単語
  #@return [Array<String>] 単語情報(辞書ファイルの1行)の配列
  def search(word)
    ret = []
    i = binary_search(word)
    if i != -1
      ret.push(@word_info[i])
      w = get_word(@word_info[i])
      ret.concat(search_backward(w,i+1))
      ret.concat(search_forward(w,i-1))
    end
    return ret
  end
  
  private
  #単語情報から単語を取得する
  #@param [String] str 単語情報
  #@return [String] 単語
  #@example 
  #  get_word("いひやつ,2165,2754,14923,動詞") #=> "いひやつ"
  def get_word(str)
    str.slice(0,str.index(","))
  end
  
  #二分探索で単語を検索する
  #@param [String] word 検索する単語
  #@return [Integer] 検索した単語のインデックス。見つからなければ-1
  def binary_search(word)
    low = 0
    hi = @word_info.size-1
    while low <= hi
      mid = (low+hi)/2
      if get_word(@word_info[mid])==word
        return mid
      end
      if get_word(@word_info[mid])<word
        low = mid+1
      else
        hi = mid-1
      end
    end
    return -1
  end
  
  #iから前方に向かってwordを検索する
  #@param [String] word 単語
  #@param [Integer] i wordのインデックス
  #@return [Array<String>] 検索結果の配列
  def search_forward(word,i)
    ret = []
    while get_word(@word_info[i])==word
      ret.push(@word_info[i])
      i-=1
    end
    return ret
  end
  
  #iから後方に向かってwordを検索する
  #@param [String] word 単語
  #@param [Integer] i wordのインデックス
  #@return [Array<String>] 検索結果の配列
  def search_backward(word,i)
    ret = []
    while get_word(@word_info[i])==word
      ret.push(@word_info[i])
      i+=1
    end
    return ret
  end
end
