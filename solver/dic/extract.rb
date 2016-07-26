# -*- coding: utf-8 -*-
#ひらがなと漢字からなる単語を抽出、漢字はひらがなに直し濁点を取り除く

require './word_converter.rb'

if ARGV.size != 2
puts "extract source out"
exit(2)
end

source = ARGV[0]
out = ARGV[1]

wc = WordConverter.new
count=0
fout = open(out,"w")
open(source){|f|
    while line = f.gets
        count += 1
        line.chomp!
        word = line[0,line.index(",")]
        if wc.hira?(word)
            line[0,word.size] = wc.remove_dakuten(word)
            fout.puts line
        elsif wc.kanji?(word)
            sword = line.split(",")
            sword[0]=wc.remove_dakuten(wc.kata_to_hira(sword[14]))
            sword[14]=word
            fout.puts sword.join(",")
        end
    end
}
fout.close
p count