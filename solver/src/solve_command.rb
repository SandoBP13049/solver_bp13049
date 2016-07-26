# -*- coding: utf-8 -*-
#翻刻制約充足問題を解かせる

require 'optparse'
require_relative './solve_execute.rb'
#require_relative './lattice.rb'

reading_file = nil
output_directory = nil
n = 1

f = open(File.expand_path('../../config.txt', __FILE__))
dic_file = f.gets.chomp
matrix_file = f.gets.chomp
da_file = f.gets.chomp
da_rev_file = f.gets.chomp
f.close

opt = OptionParser.new
opt.on('-n n','N-best探索のN 指定しない場合は1'){|v| n=v.to_i}
opt.on('-d dictionary', '--dictionary dictionary','古い形式の辞書 指定しない場合はconfig.txtに書かれているものを使用する') {|v| dic_file = v}
opt.on('-r reading','--reading reading','読みの割り当てグラフのノード(新井さんのプログラムで作成) 指定した場合は読みの割り当てグラフからコスト付き読みの割り当てグラフを作成する'){|v| reading_file = v}
opt.on('-m matrix','--matrix matrix','連接コスト行列 指定しない場合はconfig.txtに書かれているものを使用する'){|v| matrix_file=v}
opt.on('-a double_array','--da double_array','保存したDoubleArray 指定しない場合はconfig.txtに書かれているものを使用する'){|v| da_file=v}
opt.on('-b double_array_revarse','--dar double_array_revarse','保存した逆引き用DoubleArray 指定しない場合はconfig.txtに書かれているものを使用する'){|v| da_rev_file=v}
opt.on('-o output_directory','--output output_directory','指定した場合はディレクトリoutput_directoryを作成し、output_directory下にDOT言語で記述されたコスト付き読みの割り当てグラフと各解を作成する'){|v| output_directory=v}
opt.permute!(ARGV)

if ARGV.size < 1
  puts "solve csp -option"
  puts opt.help
  exit(2)
end

csp_file = ARGV[0]


solve = SolveExecute.new(csp_file,n,dic_file,reading_file,matrix_file,da_file,da_rev_file,output_directory)
solve.execute()


