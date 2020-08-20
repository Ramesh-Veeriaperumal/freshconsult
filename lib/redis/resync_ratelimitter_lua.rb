# frozen_string_literal: true

module Redis::ResyncRatelimitterLua
  mattr_accessor :resync_ratelimiter_lua

  class << self
    def resync_ratelimitter_lua_script
      Rails.logger.info 'Redis resync_ratelimitter_lua_script has been loaded'
      @resync_ratelimitter_lua_script ||= begin
        <<-LUA
        if redis.call('EXISTS', KEYS[1]) == 1 then
          if redis.call('GET', KEYS[1]) >= ARGV[1] then
            return 'true'
          else
            redis.call('INCR', KEYS[1])
            return 'false'
          end
        else
          redis.call('SET', KEYS[1], '1')
          return 'false'
        end
        LUA
      end
    end

    def load_resync_ratelimitter_lua_script
      @@resync_ratelimiter_lua = $redis_others.perform_redis_op('SCRIPT', :load, resync_ratelimitter_lua_script)
    end
  end
end
