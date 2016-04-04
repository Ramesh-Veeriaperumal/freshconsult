class AddLuaToRedis < ActiveRecord::Migration
  shard :none

  def up
    FdRateLimiter::RedisLuaScript.load_rr_lua_to_redis
  end

  def down

  end
end
