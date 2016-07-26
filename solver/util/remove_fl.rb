# -*- coding: utf-8 -*-
#文頭ノードと文末ノードが付いた解からそれらを取り除く

if ARGV.size < 1
  exit(2)
end

input_file = ARGV[0]

answers = []

f = open(input_file)
f.each_line{|line|
	if line.chomp=="" then next end
	answers.push eval(line)
}
f.close

answers.each{|a|
	p a[0][1..-2]
}
