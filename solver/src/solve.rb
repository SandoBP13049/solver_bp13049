# -*- coding: utf-8 -*-
#翻刻制約充足問題を解く
#解や計算時間は標準出力に出力するのでこのファイルを編集して調整する

require_relative './lattice.rb'
require 'optparse'

start_time = Time.now

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

csp_hash = eval(File.read(csp_file))
csp = RS::CSP::ConstraintSatisfactionProblem.new(csp_hash)
csp.insert_dummy

matrix = ConnectionMatrix.new(matrix_file)
lattice = Lattice.new
loaded_time = nil
built_time = nil
build_start_time = Time.now
if reading_file != nil
  reading = eval(File.read(reading_file))
  dic = Dictionary.new(dic_file)
  loaded_time = Time.now
  lattice.build_from_reading(csp,reading,dic,matrix)
  built_time = Time.now
else
  dic_da = DoubleArray.new
  dic_da_rev = DoubleArray.new
  dic_da.load(da_file)
  dic_da_rev.load(da_rev_file)
  loaded_time = Time.now
  lattice.build(csp,dic_da,dic_da_rev,matrix)
  built_time = Time.now
end

lattice.calc_min_cost
calculated_mincost_time = Time.now
nbests = lattice.nbest_search(n)
#puts lattice.to_dot
searched_time = Time.now

#LPBな解を残す
satisfaction_factory = RS::CSP::Evaluator::LPBSatisfactionFactory.new
solutions = []
0.upto(nbests.size-1) do |i|
  satisfaction = satisfaction_factory.create(csp.constraints)
  satisfaction.set_readings(nbests[i][0][1..-2].map(&:to_assignment).each(&:init_pos))
  tmp_solutions=[]
  addition = true
  equality = false
  solutions.each do |s|
    if s[0].comparable?(satisfaction)
      if s[0] == satisfaction
        s.push(nbests[i])
        tmp_solutions.push(s)
        addition = false
      elsif s[0] > satisfaction
        tmp_solutions.push(s)
        addition = false
      end
    else
      tmp_solutions.push(s)
    end
  end
  if addition
    tmp_solutions.push([satisfaction,nbests[i]])
  end
  solutions = tmp_solutions
end

solved_time = Time.now
if false
puts "解の数:#{solutions.inject(0){|sum,val| sum+val.size-1}}"
puts "極大充足度の数:#{solutions.size}"
puts "コスト付き読みの割当グラフのノード数:#{lattice.node_count}"
puts "合計:#{solved_time - start_time}"
puts "ファイル読み込み:#{loaded_time - start_time}"
puts "コスト付き読みの割当グラフ構築:#{built_time - loaded_time}"
puts "最小コスト計算:#{calculated_mincost_time - built_time}"
puts "N-bestの解を計算:#{searched_time - calculated_mincost_time}"
puts "制約充足度最大の解の計算:#{solved_time - searched_time}"
puts "辞書読み込みとコスト付き読みの割り当てグラフ構築:#{built_time - build_start_time}"
end
if false
puts "#{solved_time - start_time}"
puts "#{loaded_time - start_ime}"
puts "#{built_time - loaded_time}"
puts "#{calculated_mincost_time - built_time}"
puts "#{searched_time - calculated_mincost_time}"
puts "#{solved_time - searched_time}"
end

solutions=solutions.inject([]){|ret,s| ret.concat(s[1..-1])} #制約充足度を取り除く
solutions.sort!{|a,b| a[1]<=>b[1]} #総コストでソート
#solutions[0..10].each{|s| p s[1]}
#解を読みの割り当てとして出力する
#solutions.each{|solution| p solution} #文頭ノードと文末ノード付き
solutions.each{|solution| p solution[0][1..-2]} #解を出力したくない時はこの行をコメントアウト
#nbests.each{|solution| p solution} #制約を考慮する前の解

#解を文字列として出力する
#solutions.each{|solution| puts solution[0][1..-2].inject(""){|str, node| str << node.word}}

#コスト付き読みの割り当てグラフと解を指定したディレクトリにDOT言語で出力
if output_directory != nil
  if not Dir.exists?(output_directory) then Dir.mkdir(output_directory) end
  File.write("#{output_directory}/lattice.dot",lattice.to_dot)
  solutions.each_with_index do |solution,i|
    File.write("#{output_directory}/solution#{i+1}.dot",lattice.path_to_dot(solution[0]))
  end
end


