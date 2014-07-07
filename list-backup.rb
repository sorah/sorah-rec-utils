#!/usr/bin/env ruby
#
abort "usage #{File.basename($0)} dir dir dir ..." if ARGV.empty?

warnings = []
notices = []

puts ARGV.map { |_|
  Dir[File.join(File.expand_path(_), '*_*', '*')].select { |__|
    File.directory?(__) && /\d+_\d+\// === __
  }.map { |__| 
    [_, __]
  }
}.flatten(1).group_by { |parent, dir|
  dir.split(File::SEPARATOR)[-2,2].join('/')
}.sort_by(&:first).map { |basename, paths|
 paths = paths.map(&:first)


 files = Hash[paths.map do |path|
   [path, Dir[File.join(path, basename, '*.mp4')]]
 end]

 names = files.values.flatten.group_by {|_| File.basename(_) }
 names.each do |name, filepaths|
   if filepaths.size != paths.size
     dirs = filepaths.map { |_| File.dirname(_) }
     warnings.push <<-EOM
!!!!\t#{basename}/#{name}\t(#{filepaths.size}/#{paths.size})
#{paths.map { |_| dirs.include?(File.join(_, basename)) ? "!!!!\t  + #{_}" : "!!!!\t  - #{_}" }.join("\n")}
     EOM
   end
 end

 gr = names.keys.grep(/_GR/)
 bs = names.keys.grep(/_BS/)

 if (gr.size-bs.size).abs <= 2
   notices << "??? #{basename}: GR=#{gr.size}, BS=#{bs.size}"
 end

 "#{paths.size}\t#{basename}: #{paths.join(' ')}"
}.sort_by { |_| _.split(/\t/,2).first.to_i * -1 }

puts "---"

notices.each do |_|
  puts _
end

puts "---"

warnings.each do |_|
  puts _
end
