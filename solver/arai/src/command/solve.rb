#!/opt/local/bin/ruby
# -*- coding: utf-8 -*-
#

require 'optparse'
require 'rs'

opts={}
opt = OptionParser.new
opt.on('-d dictionary', '--dictionary dictionary') {|v| opts[:dictionary] = v}
opt.on('-c csp', '--csp csp') {|v| opts[:csp] = v}
opt.on('-o result', '--result result') {|v| opts[:result] = v}
opt.on('-b comparator', '--better (ucb|lpb)') {|v| opts[:better] = v}
opt.on('-s strategy', '--strategy (bcr|cac|ceh)') {|v| opts[:strategy] = v}
opt.parse!(ARGV)

if !opts[:dictionary] 
  puts "-d is mandatory."
  exit 1
end

if !opts[:csp] 
  puts "-c is mandatory."
  exit 1
end

if !opts[:better] 
  puts "-b is mandatory."
  exit 1
end

if !opts[:strategy] 
  puts "-s is mandatory."
  exit 1
end

if opts[:better] == 'ucb'
  satisfaction_factory = RS::CSP::Evaluator::UCBSatisfactionFactory.new
elsif opts[:better] == 'lpb'
  satisfaction_factory = RS::CSP::Evaluator::LPBSatisfactionFactory.new
else
  puts "-b (ucb|lpb)"
  exit 1
end

if opts[:strategy] != 'bcr' && opts[:strategy] != 'cac' && opts[:strategy] != 'ceh'
  puts "-s (bcr|cac|ceh)"
  exit 1
end

dictionaryFileName = opts[:dictionary] 

f = open(opts[:csp])
cspHash = eval f.read
f.close
csp = RS::CSP::ConstraintSatisfactionProblem.new(cspHash)

if opts[:result] 
  out = open(opts[:result], "w")
else
  out = STDOUT
end

# 時間計測開始
globalStartTime = Time.now

# 辞書の読み込み
startTime = Time.now
dictionary = RS::Dictionary::FileDictionary.new(dictionaryFileName)
#dictionary = RS::Dictionary::MemDictionary.new(dictionaryFileName)
loadDictionaryTime = Time.now - startTime

# 読みの割り当て
startTime = Time.now
assignor = RS::Assignor::ReadingAssignor.new
readings = assignor.assign_readings(csp, dictionary)
assignmentTime = Time.now - startTime 



# 読みの割り当ての書き換え
startTime = Time.now
originalReadings = Marshal.load(Marshal.dump(readings))

#p originalReadings.size
#p assignmentTime
STDERR.puts loadDictionaryTime
STDERR.puts assignmentTime 
print originalReadings.inspect
exit(1)

readings = RS::Rewriter::ReadingAssignmentShortener.new.translate(csp, readings)
tempReadings1 = Marshal.load(Marshal.dump(readings))
readings = RS::Rewriter::UnsatisfiableRARemover.new.translate(csp, readings)
tempReadings2 = Marshal.load(Marshal.dump(readings))
readings = RS::Rewriter::RepresentativeRASelector.new.translate(csp, readings)
tempReadings3 = Marshal.load(Marshal.dump(readings))
readings = RS::Rewriter::SequentialRAMerger.new.translate(csp, readings)
tempReadings4 = Marshal.load(Marshal.dump(readings))
rewriteTime = Time.now - startTime 

# 読みの合成
startTime = Time.now
#composer = RS::Composer::AllCRComposer.new(csp, readings)
#composer = RS::Composer::FewerUnreadablesCRComposer.new(csp, readings)
#composer = RS::Composer::HashedBetterCRComposer.new(csp, readings, satisfaction_factory)
composer = nil
case opts[:strategy]
when 'bcr'
  composer = RS::Composer::BetterCRComposer.new(csp, readings, satisfaction_factory)
when 'cac'
  composer = RS::Composer::SelectNodeCRComposer.new(csp, readings, satisfaction_factory)
when 'ceh'
  composer = RS::Composer::CountEveryHierarchyCRComposer.new(csp, readings, satisfaction_factory)
else
  composer = RS::Composer::CountEveryHierarchyCRComposer.new(csp, readings, satisfaction_factory)
end

composerInitializeTime = Time.now - startTime
puts "composerInitializeTime(sec):#{composerInitializeTime}"
#readings.each{|r|
#  puts "#{r.to_reading_attribute.join(',')}"
#}
composedReadings = composer.compose
#composedReadings = []
compositionTime = Time.now - startTime 

dictionary.done

totalTime = Time.now - globalStartTime

#out.puts "# 読みの総数:#{composedReadings.size}"
composedReadings.each {|x| # 連結している制約グラフへの解の集合
  out.puts "# 最適解の総数:#{x.size}"
#  x.each {|y|  # 連結している制約グラフへの解
#  out.puts "           words #{y.size}"
#  }
}
out.puts "# 辞書の読み込み(秒):#{loadDictionaryTime}"
out.puts "# 読みの割り当て(秒):#{assignmentTime}"
out.puts "# 読みの書き換え(秒):#{rewriteTime}"
out.puts "# 読みの合成   (秒):#{compositionTime}"
out.puts "# 総計        (秒):#{totalTime}"
out.puts "# 書き換え前の読みのサイズ    :#{originalReadings.size}"
out.puts "# 読みの割り当ての短縮(旧 パス併合)後の読みのサイズ:#{tempReadings1.size}"
out.puts "# 充足不能な読みの割り当て削除(旧 !削除)後の読みのサイズ:#{tempReadings2.size}"
out.puts "# 代表的な読みの割り当て選択(旧 並列ノード併合)後の読みのサイズ:#{tempReadings3.size}"
out.puts "# 直列する読みの割り当ての併合(旧 直列ノード併合)後の読みのサイズ:#{tempReadings4.size}"
out.puts
out.puts "# 元の読みの割り当て"
out.puts originalReadings.inspect
out.puts
out.puts "# 読みの割り当ての短縮(旧 パス併合)後の読みの割り当て"
out.puts tempReadings1.inspect
out.puts
out.puts "# 充足不能な読みの割り当て削除(旧 !削除)後の読みの割り当て"
out.puts tempReadings2.inspect
out.puts
out.puts "# 代表的な読みの割り当て選択(旧 並列ノード併合)後の読みの割り当て"
out.puts tempReadings3.inspect
out.puts
out.puts "# 直列する読みの割り当ての併合(旧 直列ノード併合)後の読みの割り当て"
out.puts tempReadings4.inspect
out.puts

out.puts "# 以下、最適解"
rst_size = 0
composedReadings.each {|r|
  rst_size = rst_size + r.length
  r.each {|x|
    out.puts x.inspect
  }
  out.puts
}
puts "最適解数 : #{rst_size}"
if !opts[:result] 
  out.close
end

