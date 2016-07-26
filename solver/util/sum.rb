def sum(ans)
    sum = []
    f = open(ans)
    101.times do
        name = f.gets
        f.gets
        f.gets
        array = f.gets.chomp
        f.gets
        f.gets
        next if not name.include?("M4_X0001_Y095")
        array = eval(array)
        sum << array.inject(0,:+)
    end
    f.close
    return sum
end

["00","001","01","025","05","1"].each do |a|
    name = "resultA#{a}.txt"
    s = sum(name)
    puts name
    puts s.inject(0,:+)/s.size/1300
    puts s.max
    #puts ""
end