#!/opt/local/bin/ruby
# -*- coding: utf-8 -*-

require 'optparse'
require 'rs'

opts={}
opt = OptionParser.new
opt.on('-c csp', '--csp csp') {|v| opts[:csp] = v}
opt.on('-r reading', '--reading reading') {|v| opts[:reading] = v}
opt.on('-o dot', '--out dot') {|v| opts[:out] = v}
opt.parse!(ARGV)

if !opts[:csp] 
  puts "-c is mandatory."
  exit 1
end
if !opts[:reading]
  puts "-r is mandatory."
  exit 1
end

f = open(opts[:csp])
cspHash = eval f.read
f.close
csp = RS::CSP::ConstraintSatisfactionProblem.new(cspHash)

f = open(opts[:reading])
readings = eval f.read
f.close

dot = RS::CSP::ReadingToDOT.new.translate(csp, readings)

if opts[:out] 
  f = open(opts[:out], "w")
  f.puts dot
  f.close
else
  puts dot
end

