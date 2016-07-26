require 'optparse'
require 'rs'

opts={}
opt = OptionParser.new
opt.on('-d dir', '--directory directory have texts(.txt)') {|v| opts[:text] = v}
opt.on('-o dir', '--out directory') {|v| opts[:out] = v}
opt.parse!(ARGV)

if !opts[:text] 
  puts "-t is mandatory."
  exit 1
end

TXT = ".txt"
CSP = ".csp"
index = 0

texts = Dir.glob( opts[:text] + "*" + TXT)
texts.each{|t|
  output = opts[:out] + File.basename(t).sub(TXT,"") + CSP
  input = "#{t}"
  if !system("text2csp -t #{input} -o #{output}")
    exit 1
  end
  puts "fin : #{output}"
}
