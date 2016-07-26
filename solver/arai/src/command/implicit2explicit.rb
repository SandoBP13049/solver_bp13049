#!/usr/bin/ruby
# -*- coding: utf-8 -*-
require 'optparse'
require 'rs'
$KCODE="u"

# tokenがひらがな、ゝ、々、! or ?のとき true
def token_check(token)
  return (token.value =~ /^([ぁ-ん])/u || token.value == RS::ODORIJI_1 ||  token.value == RS::ODORIJI_2 || token.value == RS::UNREADABLE_CHAR ||  token.value == RS::NOT_KANA)
end

opts={}
opt = OptionParser.new
opt.on('-t text', '--text text') {|v| opts[:text] = v}
opt.on('-o text', '--out text') {|v| opts[:out] = v}
opt.parse!(ARGV)

if !opts[:text] 
  puts "-t is mandatory."
  exit 1
end

f = open(opts[:text])
csp_description = f.read
f.close
lexer = RS::CSP::Text::Lexer.new(csp_description)
str = String.new
num = String.new
i = 1
next_token = lexer.next_token()
begin
  token = next_token
  next_token = lexer.next_token()
  #if token.value =~ /^([ぁ-ん])/u || token.value == RS::ODORIJI_1 ||  token.value == RS::ODORIJI_2 || token.value == RS::UNREADABLE_CHAR ||  token.value == RS::NOT_KANA
  if token_check(token) 
    # ひらがな、ゝ、々、! or ?のとき
    num = sprintf("%d", i)
    i += 1
    str << "x#{num} in {" + token.value
    if token.value != RS::UNREADABLE_CHAR
      str << ", !"
    end
    str << "} "
    if token_check(next_token) || next_token.kind == :LPAREN || next_token.kind == :LBRACE
      str << ", "
    end
  elsif token.kind == :LBRACE
    num = sprintf("%d", i)
    i += 1
    str << "x#{num} in " + token.value
    ec = 0
    begin
      token = next_token
      next_token = lexer.next_token()
      str << token.value
      ec += 1 if token.value == RS::UNREADABLE_CHAR
      # エラー処理が必要
    end while next_token.kind != :RBRACE
    str << ", ! " if ec == 0
    # エラー処理が必要
  else
    str << token.value + " "
    if (token.kind == :RPAREN || token.kind == :RBRACE) && (token_check(next_token) || next_token.kind == :LPAREN || next_token.kind == :LBRACE)
      str << ", "
    end
  end
end while next_token.kind != :EOT

if opts[:out] 
  f = open(opts[:out], "w")
  f.puts str
  f.close
else
  puts str
end
