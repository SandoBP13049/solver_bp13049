# -*- coding: utf-8 -*-
#DoubleArrayを構築して保存する

require_relative '../src/double_array.rb'

if ARGV.size != 2
  puts "build source out"
  exit(2)
end

source = ARGV[0]
out = ARGV[1]

da = DoubleArray.new
da.build(source)
da.save(out)