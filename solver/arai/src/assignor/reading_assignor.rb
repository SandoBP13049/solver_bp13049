# -*- coding: utf-8 -*-

#
# 辞書を引いて読みを割り当てるクラス
#
class RS::Assignor::ReadingAssignor

  public
  # 読みを割り当てる
  #
  # @return [Array<RS::CSP::ReadingAssignment>] 読みの割り当て結果の配列
  # @todo もっと単純化できると思う。
  def assign_readings(csp, dictionary)
    done = Set.new
    vars = csp.vars.dup
    while vars.size > 0 do
      v = vars.shift
      maxLength = dictionary.max_word_length(csp.domains[v])

      1.upto(maxLength) { |wordLength|
        csp.var_path(v, wordLength).each { |p|  # 変数vを含む高々長さwordLengthの変数列
          readings = dictionary.words_matched_with(csp, p, wordLength)
          readings.each do |r|
            r.init_pos
            #puts "#{r.to_reading_attribute.join(',')}"
            done.add(r)
          end
        }
      }

      w = RS::CSP::ReadingAssignment.new([v], RS::UNREADABLE_CHAR, 0)
      w.init_pos
      #puts "#{w.to_reading_attribute.join(',')}"
      done.add(w)
    end
    
    return done.to_a
  end

end
