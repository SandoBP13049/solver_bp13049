# -*- coding: utf-8 -*-
#単語を反転させた後ソートする

if ARGV.size != 2
  puts "reverse_and_sort source out"
  exit(2)
end

source = ARGV[0]
out = ARGV[1]

words = []
open(source){|f|
  while line = f.gets
    line.chomp!
    sline = line.split(",")
    if sline[0]!=""
        sline[0].reverse!
        words.push(sline)
    end
  end
}
#words.sort!{|a,b| a[0]<=>b[0]}
words.sort!{|a,b| a[0]!=b[0] ? a[0]<=>b[0] : (a[1]!=b[1] ? a[1]<=>b[1] : a[2]<=>b[2])}


f = open(out,"w")
words.each{|w|
  f.puts w[0..4].join(",")
}
f.close
