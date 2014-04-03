code = 0
$stdin.each_line do |line|
  base = line.chomp.gsub(/(\.(720|1080)p)?(\.mp4)?(\.ts)?$/, '')
  this = true
  [base+'.720p.mp4', base+'.1080p.mp4'].each do |file|
    unless File.exist?(file)
      this = false
      code = 1
      puts "#{file}: Missing"
    end
  end
  if this
    puts "#{line.chomp}: OK"

  end
  if this && ARGV[0] == '--remove'
    puts "Delete #{line.chomp}"
    File.unlink line.chomp
  end
end
exit code
