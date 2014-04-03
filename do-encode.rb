require 'fluent-logger'
require 'pathname'


def files(ext = ".1080p.mp4")
  files = Dir["*"].sort_by{|_| File::Stat.new(_).mtime }
  exts = files.group_by do |i|
    i.sub(/(\.(720|1080)p)?(\.mp4)?(\.ts)?$/, "")
  end

  exts.select! { |k, v| v.grep(/#{Regexp.escape(ext)}$/).empty? }

  exts.map do |base, files|
    files.grep(/\.ts$/).first
  end.compact
end


def tweet(tw)
  log = Fluent::Logger::FluentLogger.new("twitter", :host=>'localhost', :port=>24224)
  log.post("livermore-encode", message: tw)
end

def encode(mode, ts)
  puts "======= #{mode}: #{ts}"
  tweet "encode start: #{mode}, #{ts}"
  command = [File.join(File.dirname(__FILE__), "do-encode.#{mode}.sh"), ts]
  puts "$ #{command.join(' ')}"
  File.open('encode.log', 'a') do |io|
    io.puts "======= #{ts} "
    io.puts "$ #{command.join(' ')}"
    pid = spawn(*command, out: io, err: io)

    _, status = Process.waitpid2(pid)
    if status.success?
      tweet "encode done: #{mode}, #{ts}"
    else
      File.open('encode-failure.log', 'a') do |io2|
        io2.puts "#{mode}, #{ts}"
      end
      File.unlink ts.gsub(/\.ts$/, ".#{mode}.mp4")
      tweet "encode fail: #{mode}, #{ts}"
    end
  end
end

trap(:INT) do
  exit
end

if ARGV.size < 2
  puts "Usage: do-encode.rb mode ext"
  puts "  e.g. do-encode.rb 720p .720p.mp4"
end

mode, ext, queue_only = ARGV

restart_file = Pathname.new('/tmp').join(['restart-encoder', mode, ext, queue_only ? 'queue' : nil].compact.join('-'))
File.write restart_file, "#{Time.now.inspect}\n"
at_exit {
  begin
    restart_file.unlink if restart_file.exist?
  rescue Exception => e
    p e
  end
}


STDOUT.sync = true

Dir.chdir '../'

loop do
  if queue_only
    queue = files(ext)
    open("queue-#{mode}.txt",'w') do |queue_io|
      queue_io.puts queue.join("\n")
    end
    sleep 30
  else
    get_queue = -> do
      q = files(".720p.mp4").map{|_| ['720p', _] }
      #if 3 <= Time.now.hour && Time.now.hour <= 21
        q += files(".1080p.mp4").map{|_| ['1080p', _] }
      #end
      q
    end

    queue = get_queue[]
    while task = queue.shift
      encode(*task)
      queue = get_queue[]
    end
  end

  unless restart_file.exist?
    puts "Restarting..."
    exit 72
  end

  puts "---- no file remains. sleeping" unless queue_only
  sleep 30
end
