#!/usr/bin/env ruby
abort "usage #{File.basename($0)} dir dir dir ..."  if ENV['TV_STORAGES'].nil? && ENV['TV_STORAGES'] != '' && ARGV.empty?

ENV["BUNDLE_GEMFILE"] = "#{File.dirname(__FILE__)}/Gemfile"
require 'bundler/setup'

require 'shellwords'
require 'syoboi_calendar'

class SyoboiCalendar::QueryBuilders::Program
  option :title_id
  property :TID
  alias tid title_id
end

@syoboi = SyoboiCalendar::Client.new

TID_CACHE = "/tmp/syoboi_tids"
STOPWORD=/-|～|〜|<|>|＜|＞|,|\.|　| |・|@|＠|☆|;|\/|_|'|\(|\)|―/

CIDS = {
  "BS141" => 71, # BS ntv
  "BS151" => 18, # BS asahi
  "BS161" => 16, # BS tbs
  "BS171" => 15, # BS Japan
  "BS181" => 17, # BS fuji
  "BS191" => 204, # wowow prime
  "BS192" => 97, # wowow live
  "BS193" => 76, # wowow cinema
  "BS211" => 128, # bs11
  "BS222" => 129, # twellv
  "GR15" => 5, # tbs
  "GR16" => 19, # tokyo mx
  "GR17" => 6, # asahi
  "GR18" => 7, # tokyo
  "GR21" => 3, # fujitv
  "GR22" => 5, # tbs
  "GR23" => 7, # tokyo
  "GR24" => 6, # asahi
  "GR25" => 4, # ntv
  "GR26" => 2, # nhk e
  "GR29" => 100, # tochigi
  "GR34" => 4, # ntv
  "GR35" => 3, # fujitv
  "GR39" => 2, # nhk e
}

def failures
  @failures ||= File.read(ENV["FAILURE_LIST"] || '/mnt/data/tv/failure.txt').each_line.map do |_|
    _.chomp.sub(/(\.(720|760|1080)p)?(\.mp4)?(\.ts)?(\.progress|\.log|\.fail\d*)?$/, "")
  end
end

def cached_tids
  @cached_tids ||= begin
    tids = []
    filter = lambda do |title|
      title.tr("ａ-ｚ","a-z").
            tr("Ａ-Ｚ","a-z").gsub(/！/,'!').gsub(STOPWORD,'').gsub(/×/,'x').downcase
    end
    if File.exist?(TID_CACHE)
      open(TID_CACHE, 'r') do |io|
        io.each_line.map do |line|
          line.chomp!
          next if line.empty?
          i, t = line.split(/,/,2)
          [i.to_i, filter[t]]
        end.compact
      end
    else
      titles = @syoboi.titles(title_id: '*')
      open(TID_CACHE, 'w') do |io|
        titles.map do |title|
          name = filter[title.name]
          io.puts "#{title.id},#{name}"
          [title.id, name]
        end
      end
    end
  end
end

def queryize(str)
  str.sub(/[ 　].*$/,'').gsub(STOPWORD,'').gsub(/！/,'!').downcase
end

def search_tid(str)
  query = queryize(str)
  title_and_tids = cached_tids

  tids = title_and_tids.select { |id, name| name == query }
  if tids.empty?
    tids = title_and_tids.select { |id, name| name.start_with?(query) }
  end
  if tids.empty?
    query = str.sub(/^(.+?)(?:#{STOPWORD}).*$/,'\\1').downcase
    tids = title_and_tids.select { |id, name| name.start_with?(query) }
  end

  tids
end

@warnings = []
@notices = []

storages = ARGV + (ENV['TV_STORAGES'] ? ENV['TV_STORAGES'].split(/ /).flat_map { |_| Dir[_] } : [])
archives_by_series = storages.flat_map { |backup_root|
  Dir[File.join(File.expand_path(backup_root), '*_*', '*')].select { |series_dir|
    # make sure that is directory
    File.directory?(series_dir) && /\d+_\d+s?\// === series_dir
  }.map { |series_dir|
    [backup_root, series_dir]
  }
}.group_by { |parent, dir|
  dir[parent.size.succ .. -1]
}

puts archives_by_series.map { |series, archives_and_series_paths|
  archives = archives_and_series_paths.map(&:first)

  video_paths = archives.flat_map do |path|
    Dir[File.join(path, series, '*.mp4')]
  end

  video_paths.reject! { |_|
    if failures.any? { |f| File.basename(_).sub(/\.\d+p\.mp4$/,'') == f }
      @warnings << "- #{_} is marked as failure"
      true
    end
  }

  video_paths_by_name = video_paths.group_by {|_| File.basename(_) }

  # Warn insufficient
  video_paths_by_name.each do |name, video_paths|
    next unless video_paths.size == archives.size

    archives_of_video = video_paths.map { |_| File.dirname(_) }

    flag = nil
    lines = archives.map do |archive|
      if archives_of_video.include?(File.join(archive, series))
        "  - doesn't have #{archive}"
      else
        flag = true
        "  - have #{archive}"
      end
    end

    if flag
      @warnings.push <<-EOM
- __INSUFFICIENT__ found: #{series}/#{name} (#{video_paths.size}/#{archives.size})
#{lines.join("\n")}
      EOM
    end
  end

  videos = video_paths_by_name.keys
  gr = videos.grep(/_GR/)
  bs = videos.grep(/_BS/)

  query = if File.exist?(File.join(series, '.syoboi-query'))
    File.read(File.join(series, '.syoboi-query')).chomp
  else
    File.basename(series).sub(/_再$/,'').sub(/放課後のプレアデス/, '放課後のプレアデス(TVシリーズ)')
  end
  tids = search_tid(query)

  if tids.empty?
    @warnings << "* #{series} tids not found (query: #{queryize(query).inspect})"
  elsif 1 < tids.size
    #warnings << "* #{series} there're multiple tids: #{tids.inspect}"
  else

  end

  if 0 < gr.size && 0 < bs.size
    @notices << "- #{series}: GR=#{gr.size}, BS=#{bs.size}"

    progs = tids.flat_map do |(tid, name)|
      @syoboi.programs(title_id: tid)
    end

    video_with_progs = videos.map do |video|
      dt, ch, _ = video.sub(/\.\d+p\.mp4$/,'').split(/_/, 3)
      time = Time.new( # YYYYMMDDhhmmss
        dt[0,4].to_i, dt[4,2].to_i, dt[6,2].to_i,
        dt[8,2].to_i, dt[10,2].to_i, dt[12,2].to_i
      )
      cid = CIDS[ch]

      unless cid
        @warnings << "- unknown ch #{ch}"
        next
      end

      # simply match
      prog = progs.find { |pr| pr.channel_id == cid && pr.started_at == time }

      # if not found, try matching with date
      # (if video recorded in 00:00-04:59, it'll be also treated as previous date)
       times = nil
      prog ||= progs.find do |pr|
        st = pr.started_at
        times = [[st.year, st.month, st.day]]
        if time.hour <= 4
          st += 60 *  60 * 24
          times << [st.year, st.month, st.day]
        end

        pr.channel_id == cid && \
          times.any? { |t| [time.year, time.month, time.day] == t }
      end

      unless prog
        @warnings << "- program not found: #{time}, #{ch}, #{cid}, #{_}"
        next nil
      end

      unless prog.count
        #@warnings << "* no count attribute #{prog.id}: #{video}"
      end

      [video, prog]
    end.compact

    unknown_counter = -10000
    unknown_count = -> { unknown_counter.tap { unknown_counter += 1 } }
    videos_by_episode = video_with_progs.group_by do |(vid,prog)|
      prog.count || unknown_count[]
    end

    clean_targets = []
    videos_by_episode.to_a.sort_by(&:first).each do |count, vs|
      safe_vs = vs.reject { |(v,pr)|
        if pr.comment && pr.comment.start_with?("!") # warnings
          #@warnings << "* warn prog - #{v}: #{pr.comment}"
          true
        end
      }
      chs = safe_vs.map{ |(v,pr)| v.split(/_/,3)[1] }.uniq

      if 1 < chs.size
        @notices << "  - ##{count.to_s.rjust(3,'0')} #{vs[0][1].sub_title}: #{chs.join(", ")}"
        clean_targets.push "# -- ##{count.to_s.rjust(3,'0')} #{vs[0][1].sub_title}"
        clean_targets.push *safe_vs.reject{ |(v,pr)| /_BS/ === v }.flat_map { |(v,pr)| video_paths_by_name[v] }
      end
    end

    unless clean_targets.empty?
      @notices << "\n  ```"
      clean_targets.each do |target|
        if target.start_with?("#")
          @notices << "  #{target}"
          else
          @notices << "  rm #{target.shellescape}"
        end
      end
      @notices << "  ```\n"
    end
  end

  [archives.size, series, "- #{archives.size}:  #{series}\n#{archives.map { |a| "  - `#{a}`" }.join("\n")}"]
}.sort_by{ |_| _[0,2] }.map(&:last)

puts "\n----\n\n"

@notices.each do |_|
  puts _
end

puts "\n----\n\n"

@warnings.each do |_|
  puts _
end

