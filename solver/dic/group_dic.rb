# -*- coding: utf-8 -*-
#同じ単語(文字列)を1行にまとめる

if ARGV.size != 2
  puts "group_dic source out"
  exit(2)
end

source = ARGV[0]
out = ARGV[1]

a=[]
fout = open(out,"w")
open(source){|f|
  while line = f.gets
    line.chomp!
    if line=="" then next end
    sword = line.split(",")
    if not (a.empty? or a[0][0]==sword[0])
      fout.print a[0][0]
      a.each{|word|
        fout.print ";"
        fout.print word[1..-1].join(",")
      }
      fout.puts ""
      a.clear
    end
    a.push sword
  end
}
if not a.empty?
  fout.print a[0][0]
  a.each{|word|
    fout.print ";"
    fout.print word[1..-1].join(",")
  }
  # fout.puts ""
end
fout.close