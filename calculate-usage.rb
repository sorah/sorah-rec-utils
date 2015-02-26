#!/usr/bin/env ruby
require 'pathname'

storages = ARGV + (ENV['TV_STORAGES'] ? ENV['TV_STORAGES'].split(/ /).flat_map { |_| Dir[_] } : [])
storages.map! { |_| Pathname.new(_) }

files_flat = storages.flat_map do |storage|
  Dir[storage.join('**', '*')].map do |path|
    [storage, path.sub(/^#{Regexp.escape(storage.to_s)}/, ''), File.size(path)]
  end
end

files = files_flat.group_by { |_| _[1] }

total = 0
actual = 0
dedundancy = 0

files.each do |name, paths|
  sizes = paths.map(&:last)
  if ENV['WARN_MULTIPLE_SIZE'] && sizes.uniq.size > 1
    msg = ["WARN: #{name} has different sizes:"]
    msg.concat paths.map { |_| "#{_[0]}#{_[1]}:#{_[2]}" }
    $stderr.puts msg.join(' ')
  end

  size_sum = sizes.inject(:+)
  major_size = sizes.group_by {|_|_}.max_by {|_,__| __.size}[0]

  total += size_sum
  actual += major_size
  dedundancy += size_sum-major_size
end


def humanize(byte)
  case
  when byte >= (1024 ** 4) # T
    "%.2ft" % (byte / (1024.0 ** 4))
  when byte >= (1024 ** 3) # G
    "%.2fg" % (byte / (1024.0 ** 3))
  when byte >= (1024 ** 2) # M
    "%#.2fm" % (byte / (1024.0 ** 2))
  when byte >= 1024 # K
    "%.2fk" % (byte / 1024.0)
  else
    "#{byte}b"
  end
end

puts "total: #{total} #{humanize(total)}"
puts "actual: #{actual} #{humanize(actual)}"
puts "dedundancy: #{dedundancy} #{humanize(dedundancy)}"
