require 'redis'
Dir.chdir '../'

def ts_files_have_mp4(mode)
  files = Dir["*"].sort_by{|_| File::Stat.new(_).mtime }
  exts = files.group_by do |i|
    i.sub(/(\.(720|1080)p)?(\.mp4)?(\.ts)?(\.progress)?$/, "")
  end

  exts.select do |k, v|
    v.grep(/\.#{Regexp.escape(mode)}\.mp4(\.progress)?$/).first
  end.map { |k, v| v.grep(/\.ts(\.|\z)/) }.reject(&:empty?).flatten
end

abort "Usage: queue-maintainer.rb mode; mode = [1080p|720p]" if ARGV.size < 1
mode = ARGV.first


restart_file = Pathname.new('/tmp').join(['restart-queue-maintainer', mode].compact.join('-'))
File.write restart_file, "#{Time.now.inspect}\n"
at_exit {
  begin
    restart_file.unlink if restart_file.exist?
  rescue Exception => e
    p e
  end
}

STDOUT.sync = true
redis = Redis.new
key = "encode-queue:#{mode}"

loop do
  removable = ts_files_have_mp4(mode)
  removable.each do |ts|
    n = redis.lrem(key, 0, ts)
    if 0 < n
      puts "Cleaned #{ts} from #{key} queue"
    end
  end

  sleep 30
end
