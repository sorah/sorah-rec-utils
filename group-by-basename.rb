files = Dir["*"].sort_by{|_| File::Stat.new(_).mtime }
exts = files.inject({}) do |r,i|
  base = i.sub(/(\..+)$/, "")
  ext = $1
  r[base] ||= []; r[base] << ext
  r
end

if ARGV[0]
  exts.select! {|k,v| ARGV.all? { |e| v.include?(e) } }
end

exts.each {|k,v| puts "#{k}: #{v.join(" ")}" }
