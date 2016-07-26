# -*- coding: utf-8 -*-

require 'rubygems'
require 'sqlite3'

db = SQLite3::Database.new("unidic.db")

result = db.execute("SELECT * FROM word")
p result.size
result.each{|x|
  puts x[1]
}

db.close