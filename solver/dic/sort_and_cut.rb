# -*- coding: utf-8 -*-
#ソートし先頭から5要素(文字列,左文脈id,右文脈id,生起コスト,品詞)を残す

if ARGV.size != 2
  puts "sort_dic source out"
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
        words.push(sline)
    end
  end
}
#words.sort!{|a,b| a[0]<=>b[0]}
words.sort!{|a,b| a[0]!=b[0] ? a[0]<=>b[0] : (a[1]!=b[1] ? a[1]<=>b[1] : a[2]<=>b[2])}
#    if a[0]!=b[0]
#        next a[0]<=>b[0]
#    else
#        next a[1]<=>b[1]
#    end
#}


f = open(out,"w")
words.each{|w|
  f.puts w[0..4].join(",")
}
f.close
