encode: ./do-encode.wrap.sh
queue720: ./do-encode.wrap.sh 720p .720p.mp4 --queue
queue1080: ./do-encode.wrap.sh 1080p .1080p.mp4 --queue
redis-maintain-queue1080: bundle exec ruby queue-maintainer.rb 1080p
redis-maintain-queue720: bundle exec ruby queue-maintainer.rb 720p
