#!/usr/bin/ruby
# -*- coding: utf-8 -*-
#
# 辞書を作成する。
#

require 'optparse'
require 'rubygems'
require 'rs'
$KCODE="u"

opts={}
opt = OptionParser.new
opt.on('-o dictionary', '--dictionary dictionary') {|v| opts[:dictionary] = v}
opt.parse!(ARGV)

if !opts[:dictionary] 
  puts "-o is mandatory."
  exit 1
end

dic = RS::Dictionary::EmptyFileDictionary.new(opts[:dictionary])
conv = RS::Dictionary::WordConverter.new

# エラー数
err = 0

# 標準で追加する単語
dic.insert_word(RS::NOT_KANA)
dic.insert_word(RS::UNREADABLE_CHAR)

# 各seedファイルの単語を追加する。
ARGV.each {|seed_file|
  seed = RS::Dictionary::Seed.new(seed_file)
  words = [] # while内を実行するための値
  while words
    begin
      while words = seed.next_words
        words.each {|w|
          yomi = w.chomp    # 読み
          yomi = conv.kata_to_hira(yomi)
          yomi = conv.remove_dakuten(yomi)
          if conv.hira?(yomi)
            dic.insert_word(yomi)
          end
        }
      end
    rescue Exception => e
      STDERR.puts e.to_s
      err += 1
      words = [] # while内を実行するための値
    end
  end
}
dic.done

exit err


