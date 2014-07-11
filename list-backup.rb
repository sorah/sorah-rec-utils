#!/usr/bin/env ruby
#
abort "usage #{File.basename($0)} dir dir dir ..." if ARGV.empty?

@warnings = []
@notices = []

archives_by_series = ARGV.flat_map { |backup_root|
  Dir[File.join(File.expand_path(backup_root), '*_*', '*')].select { |series_dir|
    # make sure that is directory
    File.directory?(series_dir) && /\d+_\d+\// === series_dir
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

  video_paths_by_name = video_paths.group_by {|_| File.basename(_) }

  # Warn insufficient
  video_paths_by_name.each do |name, video_paths|
    next unless video_paths.size == archives.size

    archives_of_video = video_paths.map { |_| File.dirname(_) }

    lines = archives.map do |archive|
      if archives_of_video.include?(File.join(archive, series))
        "!!!!\t  + #{archive}"
      else
        "!!!!\t  - #{archive}"
      end
    end

    @warnings.push <<-EOM
!!!!\t#{series}/#{name}\t(#{video_paths.size}/#{archives.size})
#{lines.join("\n")}
    EOM
  end

  videos = video_paths_by_name.keys
  gr = videos.grep(/_GR/)
  bs = videos.grep(/_BS/)

  if (gr.size-bs.size).abs <= 2
    @notices << "??? #{series}: GR=#{gr.size}, BS=#{bs.size}"
  end

  "#{archives.size}\t#{series}: #{archives.join(' ')}"
}.sort_by { |_| _.split(/\t/,2).first.to_i * -1 }

puts "---"

@notices.each do |_|
  puts _
end

puts "---"

@warnings.each do |_|
  puts _
end
