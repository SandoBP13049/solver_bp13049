#!/usr/bin/ruby
require 'optparse'
require 'rs'

opts={}
opt = OptionParser.new
opt.on('-t text', '--text text') {|v| opts[:text] = v}
opt.on('-o csp', '--out csp') {|v| opts[:out] = v}
opt.parse!(ARGV)

if !opts[:text] 
  puts "-t is mandatory."
  exit 1
end

f = open(opts[:text])
csp_description = f.read
f.close
lexer = RS::CSP::Text::Lexer.new(csp_description)
parser = RS::CSP::Text::Parser.new(lexer)
exp = parser.parse()
normalizer = RS::CSP::Normalizer.new
normalized_csp = normalizer.translate(exp.to_csp_hash).inspect

if opts[:out] 
  f = open(opts[:out], "w")
  f.puts normalized_csp
  f.close
else
  puts normalized_csp
end



