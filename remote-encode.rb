require 'fluent-logger'
require 'uri'
require 'yaml'
require 'redis'

@config = YAML.load_file('config.yml')
Dir.chdir @config[:workdir]

def get_queue
  `curl -s #{@config[:queue_url]}`.each_line.map(&:chomp).reject(&:empty?)
end

def tweet(message)
  log = Fluent::Logger::FluentLogger.new("twitter", :host=>'localhost', :port=>24224)
  log.post("remote-encode", message: message)
end

redis = Redis.new(:url => @config[:redis])
key = "encode-queue:#{@config[:mode]}"
restart_file = Pathname.new('/tmp').join(['restart-remote-encoder', $$.to_s].compact.join('-'))
File.write restart_file, "#{Time.now.inspect}\n"
at_exit {
  begin
    restart_file.unlink if restart_file.exist?
  rescue Exception => e
    p e
  end
}

loop do
  until (queue = get_queue).empty?
    while file = queue.pop
      puts " * #{file}"
      redis.lrem(key, 0, file)

      if File.exists?(file)
        puts " - Skipping file download"
      else
        http_url = "#{@config[:video_url_base]}/#{URI.encode_www_form_component(file)}"

        puts "=> curl -# #{http_url}"
        unless system("curl", "-#", "-o", file, http_url)
          puts " ! failed :("
          tweet "remote-encode.#{@config[:mode]}.fail(fetch): #{file}"
          File.unlink(file) if File.exists?(file)
          redis.lpush(key, file)
          sleep 5
          next
        end
      end

      mp4 = file.sub(/\.ts$/,".#{@config[:mode]}.mp4")
      File.unlink(mp4) if File.exists?(mp4)

      sh = File.join(__dir__, "do-encode.#{@config[:mode]}.sh")
      puts "=> #{sh}"
      unless system(sh, file)
        puts " ! failed :("
        tweet "remote-encode.#{@config[:mode]}.fail: #{file}"
        redis.lpush(key, file)
        sleep 2
        next
      end


      puts "=> scp #{mp4} #{@config[:ssh_target]}:#{@config[:scp_target]}/#{mp4}.progress"
      unless system("scp", mp4, "#{@config[:scp_target]}/")
        puts " ! failed :("
        tweet "remote-encode.#{@config[:mode]}.fail(transfer): #{file}"
        redis.rpush(key, file)
        sleep 2
        next
      end

      puts "=> ssh #{@config[:ssh_target]} mv #{@config[:scp_target]}/#{mp4}.progress #{@config[:scp_target]}/#{mp4}"
      unless system("ssh", @config[:ssh_target], "mv", "#{@config[:scp_target]}/#{mp4}.progress", "#{@config[:scp_target]}/#{mp4}")
        puts " ! failed :("
        tweet "remote-encode.#{@config[:mode]}.fail(rename): #{file}"
        redis.rpush(key, file)
        sleep 2
        next
      end

      tweet "remote-encode.#{@config[:mode]}.done: #{file}"
    end

    unless restart_file.exist?
      puts "Restarting..."
      exit 72
    end

    puts "--- sleeping"
    sleep 60
  end
  sleep 90
end
