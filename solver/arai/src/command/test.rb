#!/usr/bin/ruby
# -*- coding: utf-8 -*-
require 'rs'
require 'set'

require 'runit/testcase'
require 'runit/cui/testrunner'

#
# RS::CSP::ReadingAssignmentのテストケース
#
class ReadingAssignmentTest < RUNIT::TestCase
  # テストケース
  def test1
    vars = [:x1, :x2, :x3]
    ra1 = RS::CSP::ReadingAssignment.new([:x1, :x2, :x3], "あいうえお", 1)
    assert_equal(ra1.to_a, [[:x1, :x2, :x3], ["い", "う", "え"]])
    assert_equal(ra1.to_valuation, [[:x1, "い"], [:x2, "う"], [:x3, "え"]])

    ra2 = RS::CSP::ReadingAssignment.new([:x1, :x2, :x3], "かいうえこ", 1) # 変数列に重なる読みは同じ
    ra3 = RS::CSP::ReadingAssignment.new([:x1, :x2, :x3], "かきくけこ", 1) # 単語が全然違う。
    ra4 = RS::CSP::ReadingAssignment.new([:x3, :x4, :x5], "かいうえこ", 1) # 単語も変数列も違う
    assert_equal(ra1.hash, ra2.hash)
    assert_not_equal(ra1.hash, ra3.hash)
    assert_not_equal(ra1.hash, ra4.hash)

    assert_equal(true, ra1.eql?(ra2))
    set = Set.new([ra1, ra2, ra3, ra4]) # ra1とra2は同一視されるので要素数は3
    assert_equal(3, set.size)
  end
end

RUNIT::CUI::TestRunner.run(ReadingAssignmentTest.suite)
