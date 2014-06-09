require 'fluent-logger'
require 'uri'
require 'yaml'
require 'redis'
require 'pathname'
require 'socket'

def tweet(message)
  log = Fluent::Logger::FluentLogger.new("twitter", :host=>'localhost', :port=>24224)
  log.post("encoder", message: message)
end

tweet "hi #{Time.now.to_i}"

module Encoder
  class Fail < Exception; end

  module Strategy
    class Base
      def initialize(config)
        @config = config
      end

      attr_reader :config
    end

    module Fetch
      class Curl < Base
        def fetch(path, destdir)
          url = @config[:base].gsub(/\/$/,'') + "/" + path
          dest = File.join(destdir, File.basename(path))

          cmd = ["curl", "-#", "-o", dest, url]
          $stdout.puts " * fetch $ #{cmd.join(' ')}"

          re = system(*cmd)
          raise Fail, "fetch fail #{url}" unless re

          dest
        end

        def cleanup(path, destdir)
          dest = File.join(destdir, File.basename(path))

          if File.exist?(dest)
            puts " * Cleaning #{dest}"
            File.unlink(dest)
          end
        end
      end

      class Local < Base
        def fetch(path, destdir)
          local_path = File.join(@config[:path], path)
          raise Fail, "file doesn't exist #{local_path}" unless File.exist?(local_path)

          local_path
        end

        def cleanup(path, destdir)
        end
      end
    end

    module Save
      class Scp < Base
        def save(source, destdir)
          dest = File.join(@config[:path], destdir, File.basename(source))
          dest_progress = dest + ".progress"

          cmd = ["scp", source, "#{@config[:host]}:#{dest_progress}"]

          puts " * scp $ #{cmd.join(' ')}"
          re = system(*cmd)
          raise Fail, "SCP failed #{source}" unless re

          cmd = ["ssh", @config[:host], "mv", dest_progress, dest]
          puts " * scp $ #{cmd.join(' ')}"
          re = system(*cmd)
          raise Fail, "SCP mv failed #{source}" unless re
        end
      end

      class Local < Base
        def save(source, destdir)
          dest = File.join(@config[:path], destdir, File.basename(source))

          $stdout.puts " * move #{source} -> #{dest}"
          FileUtils.mv source, dest
        end
      end
    end
  end

  class Job
    class EncodeFailed < Fail; end

    def initialize(mode, path, config)
      @mode, @source_path, @config = mode, path, config
    end

    def run
      puts "=> job #{@mode} @ #{@source_path}"
      fetch
      encode
      save
    rescue Exception => e
      puts " ! #{e.inspect}"
      e.backtrace.each do |bt|
        puts " !   #{bt}"
      end

      raise e
    else
      cleanup
    end

    def fetch
      fetch_strategy.cleanup(@source_path, @config[:workdir])

      puts " * Fetch #{@source_path.inspect}"
      @local_path = fetch_strategy.fetch(@source_path, @config[:workdir])
    end

    def encode
      dest = dest_path
      dest_progress = dest + ".progress"

      puts " * Cleaning #{dest}" if File.exist?(dest)
      puts " * Cleaning #{dest_progress}" if File.exist?(dest_progress)

      cmd = [script_path, @local_path, dest_progress]
      puts " * encode $ #{cmd.join("  ")}"
      if @config[:silent]
        re = system(*cmd, out: File::NULL, err: File::NULL)
      else
        re = system(*cmd)
      end
      raise EncodeFailed unless re

      File.rename(dest_progress, dest)
    end

    def save
      save_strategy.save(dest_path, File.dirname(@source_path))
    end

    def cleanup
      fetch_strategy.cleanup(@source_path, @config[:workdir])
      [dest_path, dest_path + ".progress"].compact.each do |file|
        if File.exist?(file)
          puts " * Clean #{file}"
          File.unlink(file)
        end
      end
    end

    private

    def script_path
      File.join(@config[:script_dir], "#{@mode}.sh")
    end

    def dest_path
      File.join(@config[:workdir], out_filename)
    end

    def out_filename
      "#{File.basename(@source_path).gsub(/\.ts$/, '')}.#{@mode}.mp4"
    end


    def fetch_strategy
      @fetch_strategy =
        Strategy::Fetch.const_get(@config[:strategy][:fetch][:type].capitalize) \
          .new(@config[:strategy][:fetch])
    end

    def save_strategy
      @save_strategy =
        Strategy::Save.const_get(@config[:strategy][:save][:type].capitalize) \
          .new(@config[:strategy][:save])
    end
  end

  class Core
    def initialize(config_file)
      @config = YAML.load_file(config_file)
      @restart_file_setup = false
    end

    def run
      setup_restart_file
      while task = get_task()
        work(task)
        check_restart_file
      end
    end

    def get_task
      puts " = watching #{queue_keys}"
      redis.blpop(queue_keys)
    end

    def work(task)
      queue, source_path = task
      mode = queue.split(/:/).last
      tweet "encode.#{Socket.gethostname}.#{mode}.start: #{source_path}"

      redis.hset working_key(mode), source_path, Time.now.to_i

      job = Job.new(mode, source_path, @config)
      job.run
      tweet "encode.#{Socket.gethostname}.#{mode}.done: #{source_path}"
      redis.hdel working_key(mode), source_path
      true
    rescue Exception => e
      tweet "encode.#{Socket.gethostname}.#{mode}.fail(@sorahers ): #{e.class} #{source_path}"
      puts "  ! FAILED: #{e.inspect}"
      if source_path && mode
        puts "  ! Requeueing"
        redis.hdel working_key(mode), source_path
        redis.rpush queue_key(mode), source_path
      end
      sleep 10
      false
    end

    private

    def restart_file
      @restart_file ||= Pathname.new('/tmp').join(['restart-encoder', $$.to_s].compact.join('-'))
    end

    def setup_restart_file
      @restart_file_setup = true
      File.write restart_file, "#{Time.now.inspect}\n"
      at_exit {
        begin
          restart_file.unlink if restart_file.exist?
        rescue Exception => e
          p e
        end
      }
    end

    def check_restart_file
      if @restart_file_setup && !restart_file.exist?
        puts "Restarting..."
        tweet "#{Socket.gethostname}.encode.restart: #{Time.now.to_i}"
        Kernel.exec "ruby", __FILE__, *ARGV
      end
    end

    def redis
      @redis ||= Redis.new(:url => @config[:redis])
    end

    def queue_keys
      @queue_keys ||= [*@config[:mode]].map { |_| queue_key(_) }
    end

    def queue_key(mode)
      "encode-queue:#{mode}"
    end

    def working_key(mode)
      "encode-working:#{mode}"
    end
  end
end

Encoder::Core.new(ARGV[0] || 'config.yml').run
