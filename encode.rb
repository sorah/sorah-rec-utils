require 'fluent-logger'
require 'uri'
require 'json'
require 'redis'
require 'pathname'
require 'socket'
require 'shellwords'

module Encoder
  class Fail < Exception; end
  module Fails
    class FetchFail < Fail; end
    class SaveFail < Fail; end
    class EncodeFail < Fail; end
  end

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

          url.gsub!(/#/,'%23')
          cmd = ["curl", "--fail", "--globoff", "-#", "-o", dest, url]
          $stdout.puts " * fetch $ #{cmd.join(' ')}"

          re = system(*cmd)
          raise Fails::FetchFail, "fetch fail #{url}" unless re

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
          raise Fails::FetchFail, "file doesn't exist #{local_path}" unless File.exist?(local_path)

          local_path
        end

        def cleanup(path, destdir)
        end
      end

      class Ffmpeg < Base
        def fetch(path, destdir)
          url = @config[:base].gsub(/\/$/,'') + "/" + path
          url
        end

        def cleanup(path, destdir)
        end
      end
    end

    module Save
      class Scp < Base
        def initialize(*)
          super

          @cmd_prefix = []
          remote_shell = IO.popen(["ssh", @config[:host], "echo", "$SHELL"], 'r', &:read).chomp

          if remote_shell.split(?/).last == "zsh"
            puts "  * remote shell is zsh, using noglob"
            @cmd_prefix = ["noglob"]
          end
        end

        def save(source, destdir)
          dest = File.join(@config[:path], destdir, File.basename(source))
          dest_progress = dest + ".progress"

          cmd = ["scp", source, "#{@config[:host]}:#{dest_progress.shellescape}"]

          puts " * scp $ #{cmd.join(' ')}"
          re = system(*cmd)
          raise Fails::SaveFail, "SCP failed #{source}" unless re

          cmd = ["ssh", @config[:host], *@cmd_prefix, ["mv", dest_progress, dest].shelljoin]
          puts " * scp $ #{cmd.join(' ')}"
          re = system(*cmd)
          raise Fails::SaveFail, "SCP mv failed #{source}" unless re
        end
      end

      class Webdav < Base
        def save(source, destdir)
          dest = [destdir, File.basename(source)].join(?/)
          url = @config[:base].gsub(/\/$/,'') + "/" + dest
          url.gsub!(/#/,'%23')

          user = @config[:user] && ['-u', @config[:user]]
          cmd = ["curl", *user, "-o", "-", "--fail", "--globoff", "--upload-file", source, "-X", "PUT", "-D", '-', url]

          $stdout.puts " * save url: #{url}"
          $stdout.puts " * save $ #{cmd.join(' ')}"

          re = system(*cmd)
          raise Fails::SaveFail, "save fail #{url}" unless re

          dest
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

      cleanup if @config[:cleanup_even_on_failure]
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
      puts " > #{log_path}"

      re = nil
      File.symlink(log_path, "#{current_log_path}.new")
      File.open(log_path, "w") do |io|
        File.rename("#{current_log_path}.new", current_log_path)
        re = system(*cmd, out: io, err: io)
      end
      raise Fails::EncodeFail unless re

      File.rename(dest_progress, dest)
    end

    def save
      if File.realpath(dest_path) == File::NULL
        puts " * Skipping save (File::NULL)"
        return 
      end
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

    def log_path
      File.join(@config[:log_dir], "#{out_filename}.log")
    end

    def current_log_path
      File.join(@config[:log_dir], "current.log")
    end

    def out_filename
      ext = case @mode
            when 'ass'; 'ass'
            else; 'mp4'
            end
      "#{File.basename(@source_path).gsub(/\.ts$/, '')}.#{@mode}.#{ext}"
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
      @config = JSON.parse(File.read(config_file), symbolize_names: true)
      @restart_file_setup = false
    end

    def fluent
      @fluent_logger ||= Fluent::Logger::FluentLogger.new(@config[:fluentd][:prefix], :host => @config[:fluentd][:host] || 'localhost', :port => (@config[:fluentd][:port] || 24224).to_i)
    end

    def fluent_log(key, data={})
      host = Socket.gethostname
      message_prefix = ['encode', host, data[:mode], key].compact.join('.')
      payload = {
        host: host,
        state: key.to_s,
        time: Time.now.to_i, 
        message_prefix: message_prefix,
        orig_message: data[:message],
      }.merge(data)
      payload[:message] = "#{message_prefix}: #{data[:job]} #{data[:message]}"

      fluent.post(key.to_s, payload)
    end

    def run
      fluent_log :boot, message: Time.now.to_s
      setup_restart_file
      while task = get_task()
        work(task)
        check_restart_file
      end
    end

    def get_task
      keys = ordered_queue_keys
      puts " = watching #{keys}"
      redis.blpop(keys)
    end

    def work(task)
      queue, source_path = task
      mode = queue.split(/:/).last

      fluent_log :start, mode: mode, job: source_path
      start_time = Time.now.to_i

      redis.hset working_key(mode), source_path, start_time

      job = Job.new(mode, source_path, @config)
      job.run

      end_time = Time.now.to_i

      fluent_log :done, mode: mode, job_duration: end_time-start_time, job: source_path
      redis.hdel working_key(mode), source_path
      true
    rescue Exception => e
      puts "  ! FAILED: #{e.inspect}\n  ! #{e.backtrace.join("\n  ! ")}"

      fluent_log(:error,
        job: source_path,
        mode: mode,
        error_class: e.class.inspect,
        error_message: e.message,
        error_backtrace: e.backtrace,
        message: "#{e.class} @sorahers",
        long_message: "#{e.class}: #{e.message}\n\t#{e.backtrace.join("\n\t")}",
      )

      if source_path && mode
        puts "  * Requeueing"
        redis.hdel working_key(mode), source_path
        redis.rpush(*task)
      end

      if e.is_a?(SignalException)
        puts "Shutting down!"
        exit
      end

      sleep 10
      false
    end

    private

    def restart_file
      @restart_file ||= Pathname.new('/run/encoder').join(['restart', $$.to_s].compact.join('-'))
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
        fluent_log :restart, message: Time.now.to_s
        Kernel.exec "ruby", __FILE__, *ARGV
      end
    end

    def redis
      @redis ||= Redis.new(:url => @config[:redis])
    end

    def ordered_queue_keys
      if @ordered_queue_keys
        @ordered_queue_keys.each do |chunk|
          chunk << chunk.shift
        end
      else
        @ordered_queue_keys = queue_keys
      end

      @ordered_queue_keys.flatten
    end

    def queue_keys
      @queue_keys ||= [*@config[:mode]].map do |_|
        case _
        when Array
          _.map { |__| queue_key(__) }
        else
          [queue_key(_)]
        end
      end
    end

    def queue_key(mode)
      "encode-queue:#{mode}"
    end

    def working_key(mode)
      "encode-working:#{mode}"
    end

    def hostname
      Socket.gethostname
    end
  end
end

Encoder::Core.new(ARGV[0] || 'config.json').run
