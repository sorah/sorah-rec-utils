require 'fluent-logger'
require 'uri'
require 'yaml'

@config = YAML.load_file('config.yml')
Dir.chdir @config[:workdir]

def get_queue
  `curl -s #{@config[:queue_url]}`.each_line.map(&:chomp).reject(&:empty?)
end

def tweet(message)
  log = Fluent::Logger::FluentLogger.new("twitter", :host=>'localhost', :port=>24224)
  log.post("remote-encode", message: message)
end

loop do
  until (queue = get_queue).empty?
    while file = queue.pop
      puts " * #{file}"

      if File.exists?(file)
        puts " - Skipping file download"
      else
        http_url = "#{@config[:video_url_base]}/#{URI.encode_www_form_component(file)}"

        puts "=> curl -# #{http_url}"
        unless system("curl", "-#", "-o", file, http_url)
          puts " ! failed :("
          tweet "remote-encode.#{@config[:mode]}.fail(fetch): #{file}"
          sleep 5
          next
        end
      end

      sh = File.join(__dir__, "do-encode.#{@config[:mode]}.sh")
      puts "=> #{sh}"
      unless system(sh, file)
        puts " ! failed :("
        tweet "remote-encode.#{@config[:mode]}.fail: #{file}"
        sleep 2
        next
      end

      mp4 = file.sub(/\.ts$/,'.1080p.mp4')

      puts "=> scp #{mp4} #{@config[:scp_target]}/"
      unless system("scp", mp4, "#{@config[:scp_target]}/")
        puts " ! failed :("
        tweet "remote-encode.#{@config[:mode]}.fail(transfer): #{file}"
        sleep 2
        next
      end

      tweet "remote-encode.#{@config[:mode]}.done: #{file}"
    end
    puts "--- sleeping"
    sleep 60
  end
  sleep 90
end
