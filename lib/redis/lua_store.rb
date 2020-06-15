class Redis::LuaStore
  class << self
    # Evaluate a Lua script by Lua script or its SHA code.
    #
    # @param client - Redis client
    # @param <String> lua_script - Lua script
    # @param <String> lua_sha - SHA code of the Lua script
    # @param [Array<String>] keys - optional array with keys to pass to the script
    # @param [Array<String>] args - optional array with arguments to pass to the script
    #
    def evaluate(client, lua_script, lua_sha, keys, args)
      result = nil
      begin
        result = client.safe_send(:evalsha, lua_sha, keys, args)
      rescue Redis::BaseError => e
        Rails.logger.debug "Redis Error, #{e.message}"
        result = client.send(:eval, lua_script, keys, args) if e.message.include?('NOSCRIPT No matching script')
      end
      result
    end
  end
end
