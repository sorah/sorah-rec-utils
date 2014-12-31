#!/usr/bin/env ruby

abort "usage #{File.basename($0)} series_from series_to dir dir dir ..." if ENV['TV_STORAGES'] ? (ARGV.size < 2) : (ARGV.size < 3)

from, to = ARGV.shift(2)

storages = ARGV + (ENV['TV_STORAGES'] ? ENV['TV_STORAGES'].split(/ /).flat_map { |_| Dir[_] } : [])
storages.each do |archive|
  src = File.join(archive, from)
  if File.exist?(src)
    dst = File.join(archive, to)
    puts "=> #{src} -> #{dst}"
    File.rename(src,dst)
  else
    puts " - #{archive}"
  end
end
