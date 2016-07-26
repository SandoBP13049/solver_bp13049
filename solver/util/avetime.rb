#実行時間の平均を求める
#使いやすくはしていない
code = ARGV[0]
n = ARGV[1].to_i
count = ARGV[2].to_i
result=[]
count.times do
	result << `ruby solve.rb ../csp/ise#{code}_c1.csp ../reading_uni/reading#{code}_uni.txt #{n}`
end

v=[]
result.each do |out|
	t=[]
	out.each_line do |line|
		t << line.to_f
	end
	v << t
end
#p v
#一番時間が短い解と長い解を除いて平均をとる
v.sort!{|a,b| a[1]<=>b[1]}
v = v[1..-2].transpose
v.each do |val|
	puts val.inject(0.0){|sum,i| sum+i}/val.size
end