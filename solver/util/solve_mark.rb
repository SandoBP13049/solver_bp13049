csp_dir = ARGV[0]
ans_dir = ARGV[1]

Dir.mkdir(ans_dir) if not File.exists?(ans_dir)

Dir.glob(csp_dir + '/*.csp').each do |csp|
    name = File.basename(csp,'.csp')
    `ruby src/solve2.rb #{csp} -n 10 > #{ans_dir}/#{name}.txt`
    STDERR.puts csp
end

Dir.glob(ans_dir + '/*.txt').each do |ans|
    name = File.basename(ans,'.txt')
    puts `ruby src/mark.rb #{csp_dir}/#{name}.csp new_ans/right_ans_jtk.txt #{ans}`
    puts ""
end