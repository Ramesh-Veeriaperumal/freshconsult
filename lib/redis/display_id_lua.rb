module Redis::DisplayIdLua

  mattr_accessor :redis_lua_script_sha, :picklist_id_lua_script

  class << self

    def get_display_id_lua_script
      puts 'Redis Lua Script has been loaded'
      lua_script = <<-LUA
        local key
        if redis.call('EXISTS', ARGV[1]) == 1 then
          key = redis.call('INCR', ARGV[1])
          return key
        else
          redis.call('SET', ARGV[1],'#{TicketConstants::TICKET_START_DISPLAY_ID}')
          key = redis.call('GET', ARGV[1])
          return key
        end
      LUA
    end

    def load_display_id_lua_script_to_redis
      @@redis_lua_script_sha = $redis_display_id.perform_redis_op("SCRIPT", :load, get_display_id_lua_script)
    end

    def get_picklist_id_lua_script
      puts 'Redis Lua Script has been loaded'
      lua_script = <<-LUA
        local key
        if redis.call('EXISTS', ARGV[1]) == 1 then
          key = redis.call('INCR', ARGV[1])
          return key
        else
          redis.call('SET', ARGV[1],'1')
          key = redis.call('GET', ARGV[1])
          return key
        end
      LUA
    end

    def load_picklist_id_lua_script
      @@picklist_id_lua_script = $redis_display_id.perform_redis_op("SCRIPT", :load, get_picklist_id_lua_script)
    end    

  end

end
