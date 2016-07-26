# -*- coding: utf-8 -*-
#重複している単語(語と文脈idが同じ)があれば生起コストが最小のものを残す

if ARGV.size != 2
puts "unique source out"
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
    	if not (a.empty? or (a[0][0]==sword[0] and a[0][1]==sword[1] and a[0][2]==sword[2]))
    		fout.puts (a.min{|x,y| x[3].to_i <=> y[3].to_i}).join(",")
    		#fout.puts (a.max{|x,y| x[3].to_i <=> y[3].to_i}).join(",")
    		#a[0][3] = a.inject(0){|sum,v| sum + v[3].to_i}/a.size
    		#fout.puts a[0].join(",")
    		a.clear
    	end
    	a.push sword
    end
}
if not a.empty?
	fout.puts a.min{|x,y| x[3].to_i <=> y[3].to_i}.join(",")
end
fout.close