#!/usr/bin/env ruby
# coding: utf-8
# https://gist.github.com/eagletmt/5810946
# Usage: sd-hd.rb TS_FILE [--write]
require 'open3'

class Avconv
  def initialize(path, bin = 'ffmpeg')
    @path = path
    @bin = bin
  end

  def skip(t)
    pipeline = skip_pipeline(t) + ["#{@bin} -i - 2>&1"]
    Open3.pipeline_r(*pipeline) do |r, args|
      r.read
    end
  end

  def cuttable?(t)
    cmd = %W[#{@bin} -loglevel quiet -i - -acodec copy -vcodec copy -f mpegts -t 20 -y #{File::NULL}]
    pipeline = skip_pipeline(t) + [cmd]
    ts = Open3.pipeline_r *pipeline
    ts.last.success?
  end

  def skip_pipeline(t)
    [
      ['tail', '-c', "+#{188*t}", @path],
      ['head', '-c', '18800000'],
    ]
  end
end

SD_SIZE = '720x480'
HD_SIZE = '1440x1080'
MAIN_STREAM = 'Stream #0:0'# 'Stream #0.0'

def bsearch(avconv, lo, hi, &blk)
  truthy = false
  while lo < hi
    mid = (lo + hi)/2
   $stderr.puts [lo, hi, mid].inspect
    lines = avconv.skip(mid).lines
    if lines.any? { |line| line.include?(MAIN_STREAM) and line.include?(HD_SIZE) }
      $stderr.puts lines.find { |line| line.include?(MAIN_STREAM) and line.include?(HD_SIZE) }
      if blk.nil? or blk.call(mid)
        truthy = true
        hi = mid
      else
        lo = mid+1
      end
    elsif lines.any? { |line| line.include?(MAIN_STREAM) and line.include?(SD_SIZE) }
      $stderr.puts lines.find { |line| line.include?(MAIN_STREAM) and line.include?(SD_SIZE) }
      lo = mid+1
    else
      $stderr.puts "Error at mid=#{mid}"
      lo = mid+1
      #raise "Error at mid=#{mid}"
    end
  end
  return [lo, truthy]
end

path = ARGV[0] or exit 1
write = ARGV[1]
avconv = Avconv.new path

MAX_PACKETS = 300000
# avconv -i が HD_SIZE になるところを見つけてから、それより後ろで cuttable なところを見つける
lo, __ = bsearch(avconv, 0, MAX_PACKETS)
$stderr.puts lo.inspect
$stderr.puts '-----'

ans, truthy = bsearch(avconv, lo, MAX_PACKETS) do |t|
  avconv.cuttable?(t)
end

ans = lo unless truthy

$stderr.puts "Answer: #{ans}"
write_cmd = ["tail", "-c", "+#{188*ans}", path]

puts write_cmd.join(" ")

write_path = path + ".cutted"

if ans != 0 && write
  open(write_path, "w") do |io|
    system *write_cmd, out: io
  end
  File.rename path, "#{path}.uncutted"
  File.rename write_path, path
end
