# -*- coding: utf-8 -*-
#ランダムに単語を抽出しソートする
#第3引数には割合(%)を入力する

if ARGV.size != 3
  puts "rand_ext source out p"
  exit(2)
end

source = ARGV[0]
out = ARGV[1]
p = ARGV[2].to_f

words = []
open(source){|f|
  while line = f.gets
    line.chomp!
    sline = line.split(",")
    if sline[0]!=""
        words.push(sline)
    end
  end
}
words.shuffle!

n = (words.size*p/100).to_i

f = open(out,"w")
words[0,n].sort{|a,b| a[0]!=b[0] ? a[0]<=>b[0] : (a[1]!=b[1] ? a[1]<=>b[1] : a[2]<=>b[2])}.each{|w|
	f.puts w.join(",")
}
f.close
