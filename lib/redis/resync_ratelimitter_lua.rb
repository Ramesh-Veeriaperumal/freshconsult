# frozen_string_literal: true

module Redis::ResyncRatelimitterLua
  mattr_accessor :resync_ratelimiter_lua

  class << self
    def resync_ratelimitter_lua_script
      Rails.logger.info 'Redis resync_ratelimitter_lua_script has been loaded'
      @resync_ratelimitter_lua_script ||= begin
        <<-LUA
        if ARGV[1] == 'INCR' then
          return redis.call('INCR', KEYS[1])
          elseif ARGV[1] == 'DECR' then
          return redis.call('DECR', KEYS[1])
        else
          return redis.call('GET', KEYS[1])
        end
        LUA
      end
    end

    def load_resync_ratelimitter_lua_script
      @@resync_ratelimiter_lua = $redis_others.perform_redis_op('SCRIPT', :load, resync_ratelimitter_lua_script)
    end
  end
end
