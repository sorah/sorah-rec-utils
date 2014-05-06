require 'redis'
require 'fileutils'

Dir.chdir "#{__dir__}/../.."
redis = Redis.new

targets = Dir["./201405*_GR16_*uncutted"]

targets.each do |uncutted|
  puts "=> #{uncutted}"
  ts = uncutted.sub(/(?:\.progress)?\.uncutted$/,'')
  puts " * -> #{ts}"

  cut_cmd = IO.popen(['ruby', './scripts/sd-hd.rb', uncutted, err: File::NULL], 'r', &:read).chomp.split(/ /, 4)
  raise 'something went wrong' unless $?.success?

  File.delete(ts) if File.exist?(ts)

  if cut_cmd[2] == "+0"
    puts " * Copying..."
    FileUtils.cp uncutted, ts
  else
    puts " * Cutting..."
    open(ts, 'w') do |io|
      system *cut_cmd, out: io
    end
  end

  mp4_720p = ts.sub(/\.ts$/, '.720p.mp4')
  mp4_1080p = ts.sub(/\.ts$/, '.1080p.mp4')
  if File.exist?(mp4_720p)
    puts " * Removing 720p.mp4"
    File.unlink(mp4_720p)
  end
  if File.exist?(mp4_1080p)
    puts " * Removing 1080p.mp4"
    File.unlink(mp4_1080p)
  end

  basename = File.basename(ts)
  redis.lrem 'encode-queue:720p', 0, basename
  redis.lrem 'encode-queue:1080p', 0, basename
  redis.lpush 'encode-queue:720p', basename
  redis.lpush 'encode-queue:1080p', basename
end
