#!/usr/bin/env ruby
# coding: utf-8

# based on https://github.com/eagletmt/eagletmt-recutils
# Copyright (c) 2014 Kohei Suzuki
# 
# MIT License
# 
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
# 
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

require 'time'

_, st = *File.basename(ARGV[0]).match(/\A(?:\d{4}\d{2}\d{2})?(\d{2}\d{2}\d{2})(?:_|\z)/)
st = Time.strptime st, '%H%M%S'
sc = 0#sc.to_i
open(ARGV[1], 'r') do |fin|
  started = false
  fin.readlines.each do |line|
    m = line.match(/^Dialogue: 0,(\d{2}:\d{2}:\d{2}).(\d{2}),(\d{2}:\d{2}:\d{2}).(\d{2}),(.*)$/) rescue nil
    if m
      _, t1, c1, t2, c2, rest = *m
      t1, t2 = *[t1, t2].map { |t| Time.strptime t, '%H:%M:%S' }
      c1, c2 = *[c1, c2].map(&:to_i)
      c1 -= sc
      if c1 < 0
        c1 += 100
        t1 -= 1
      end
      c2 -= sc
      if c2 < 0
        c2 += 100
        t2 -= 1
      end
      d1 = (t1 - st).to_i
      if d1 < 0
        if started
          d1 += 24*60*60
        else
          next
        end
      end
      started = true
      d2 = (t2 - st).to_i
      if d2 < 0
        d2 += 24*60*60
      end
      h1 = d1 / 3600
      h2 = d2 / 3600
      d1 %= 3600
      d2 %= 3600
      m1 = d1 / 60
      m2 = d2 / 60
      s1 = d1 % 60
      s2 = d2 % 60
      printf "Dialogue: 0,%02d:%02d:%02d.%02d,%02d:%02d:%02d.%02d,%s\n", h1, m1, s1, c1, h2, m2, s2, c2, rest
    else
      puts line
    end
  end
end
