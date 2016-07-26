# -*- coding: utf-8 -*-

require_relative './marker'
#require 'constraint_satisfaction_problem'

if ARGV.size < 3
  puts "mark csp right_answer answer (n)"
  exit(2)
end

csp_file = ARGV[0]
right_answer_file = ARGV[1]
answer_file = ARGV[2]

csp_hash = eval(File.read(csp_file))
csp = RS::CSP::ConstraintSatisfactionProblem.new(csp_hash)

marker = Marker.new(csp)

marker.right_answer = eval(File.read(right_answer_file))

answers = File.readlines(answer_file).reject{|line| line.chomp == ""}.map{|line| eval(line)}
max_point = marker.max_point

if ARGV.size > 3
    answers = answers[0,ARGV[3].to_i]
end

points = answers.map{|answer| marker.mark(answer)}
sum = points.inject(0.0, :+)
points.each{|point|
  #puts "#{point}点 得点率:#{point/max_point}"
}
puts answer_file
puts "解数#{answers.size} 最大得点#{max_point}"
puts "平均#{sum/answers.size}点 平均得点率:#{sum/answers.size/max_point} 最高点:#{points.max} 最低点:#{points.min}"
#p "#{marker.mark(answer)}/#{marker.max_point}"
p points
puts ""