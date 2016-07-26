#require './rs/constraint_satisfaction_program.rb'
#cspの情報(ここでは変数の数と各制約階層の制約の数)を出力する

csp_file = ARGV[0]
f = open(csp_file)
csp_hash = eval(f.read)
f.close
#csp = RS::CSP::ConstraintSatisfactionProblem.new(csp_hash)

p csp_hash[:vars].size
csp_hash[:constraints].each{|c|
	p c.size
}