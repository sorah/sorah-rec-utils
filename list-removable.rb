#!/usr/bin/env ruby

def files
  files = Dir["*"].sort_by{|_| File::Stat.new(_).mtime }
  exts = files.group_by do |i|
    i.sub(/(\.(720|760|1080)p)?(\.mp4)?(\.ts)?$/, "")
  end

  exts.select do |k, v|
    v.grep(/\.720p\.mp4$/).first && v.grep(/\.1080p\.mp4$/).first
  end.map { |k, v| v.grep(/\.ts(\.|\z)/) }.reject(&:empty?)
end

puts files
