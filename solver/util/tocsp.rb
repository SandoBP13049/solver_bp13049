txt_dir = ARGV[0]
csp_dir = ARGV[1]

Dir.glob(txt_dir + '/*.txt').each do |txt|
    name = File.basename(txt,'.txt')
    `arai/bin/text2csp -t #{txt} -o #{csp_dir}/#{name}.csp`
end