#!/usr/bin/env ruby
#
abort "usage #{File.basename($0)} dir dir dir ..." if ARGV.empty?

ARGV.map { |_|
  Dir[File.join(File.expand_path(_), '*_*')].select { |__|
    File.directory?(__) && /^\d+_\d+$/ === File.basename(__)
  }.map { |__| 
    [_, __]
  }
}.flatten(1).group_by { |parent, dir|
  File.basename(dir)
}.sort_by(&:first).map { |basename, paths|
 paths = paths.map(&:first)

 puts "#{basename}(#{paths.size}): #{paths.join(' ')}"
}
