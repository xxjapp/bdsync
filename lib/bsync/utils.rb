require "digest"

module Bsync
    module Utils
        # Examples:
        #
        # puts Utils.timestamp
        # > 2019-12-11.16-15-57
        #
        # puts Utils.timestamp[0...10].delete("-")
        # > 20191211
        #
        def self.timestamp
            ts = Time.now.to_s[0..18]
            ts[10] = "."
            ts[13] = ts[16] = "-"

            ts
        end

        def self.md5(s)
            Digest::MD5.hexdigest(s)
        end

        def self.caller_info level
            info = caller[level].match(%r{([^/]+):(\d+):in `(.+)'})
            "#{info.captures[0]}:#{info.captures[1]} - #{info.captures[2]}"
        end

        def self.try_lock
            File.open(__FILE__, 'r').flock(File::LOCK_EX | File::LOCK_NB)
        end
    end
end
