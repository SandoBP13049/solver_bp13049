#!/usr/bin/ruby
# -*- coding: euc-jp -*-
require 'optparse'
require 'rs'

opts={}
opt = OptionParser.new
opt.on('-c csp', '--csp csp') {|v| opts[:csp] = v}
opt.on('-o dot', '--out dot') {|v| opts[:out] = v}
opt.parse!(ARGV)

if !opts[:csp] 
  puts "-c is mandatory."
  exit 1
end
f = open(opts[:csp])
csp_hash = eval(f.read)
f.close
csp = RS::CSP::ConstraintSatisfactionProblem.new(csp_hash)
dot = RS::CSP::CSPToDOT.new.translate(csp)

if opts[:out] 
  f = open(opts[:out], "w")
  f.puts dot
  f.close
else
  puts dot
end
