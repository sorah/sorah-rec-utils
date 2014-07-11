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

puts archives_by_series.map { |series, paths|
  paths = paths.map(&:first)


  files = Hash[paths.map do |path|
    [path, Dir[File.join(path, series, '*.mp4')]]
  end]

  names = files.values.flatten.group_by {|_| File.basename(_) }
  names.each do |name, filepaths|
    if filepaths.size != paths.size
      dirs = filepaths.map { |_| File.dirname(_) }
      @warnings.push <<-EOM
!!!!\t#{series}/#{name}\t(#{filepaths.size}/#{paths.size})
#{paths.map { |_| dirs.include?(File.join(_, series)) ? "!!!!\t  + #{_}" : "!!!!\t  - #{_}" }.join("\n")}
      EOM
    end
  end

  gr = names.keys.grep(/_GR/)
  bs = names.keys.grep(/_BS/)

  if (gr.size-bs.size).abs <= 2
    @notices << "??? #{series}: GR=#{gr.size}, BS=#{bs.size}"
  end

  "#{paths.size}\t#{series}: #{paths.join(' ')}"
}.sort_by { |_| _.split(/\t/,2).first.to_i * -1 }

puts "---"

@notices.each do |_|
  puts _
end

puts "---"

@warnings.each do |_|
  puts _
end
