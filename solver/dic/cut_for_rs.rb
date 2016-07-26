# -*- coding: utf-8 -*-
#新井さんの辞書のシードとして使用できる形に変換する

if ARGV.size != 2
  puts "cut_for_rs source out"
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
    	if not (a.empty? or (a[0][0]==sword[0]))
    		fout.puts a[0][0]
    		a.clear
    	end
    	a.push sword
    end
}
if not a.empty?
	fout.puts a[0][0]
end
fout.close