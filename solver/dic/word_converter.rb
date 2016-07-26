# -*- coding: utf-8 -*-
#$KCODE="u"

#
# 辞書に登録する単語を正規化するメソッドを持つクラス
#
class WordConverter

  public
  # ひらがなと長音記号とだけからなる文字列?
  # @param [String] text 
  # @return [true, false] ひらがなと長音記号とだけからなる文字列ならtrue, そうでなければfalse。
  def hira?(text)
    if /^[ぁ-んー]+$/u =~ text
      return true
    end
    return false
  end
  
  def kanji?(text)
    if /\p{Han}/u =~ text
        return true
    else
        return false
    end
  end


  public
  # カタカナをひらがなに変換する。
  # @param [Strig] katakana
  # @return [String] カタカナをひらがなに変換した結果
  def kata_to_hira(katakana)
    katakana.tr("ァ-ン", "ぁ-ん")
  end

  public
  # 登録する語の正規化
  # @param [String] word 正規化する語
  # @return [String] 正規化結果
  def remove_dakuten(word)
    result = word.dup

    result.tr!("が", "か")
    result.tr!("ぎ", "き")
    result.tr!("ぐ", "く")
    result.tr!("げ", "け")
    result.tr!("ご", "こ")

    result.tr!("ざ", "さ")
    result.tr!("じ", "し")
    result.tr!("ず", "す")
    result.tr!("ぜ", "せ")
    result.tr!("ぞ", "そ")

    result.tr!("だ", "た")
    result.tr!("ぢ", "ち")
    result.tr!("づ", "つ")
    result.tr!("で", "て")
    result.tr!("ど", "と")

    result.tr!("ば", "は")
    result.tr!("び", "ひ")
    result.tr!("ぶ", "ふ")
    result.tr!("べ", "へ")
    result.tr!("ぼ", "ほ")

    result.tr!("ぱ", "は")
    result.tr!("ぴ", "ひ")
    result.tr!("ぷ", "ふ")
    result.tr!("ぺ", "へ")
    result.tr!("ぽ", "ほ")

    return result
  end

end
