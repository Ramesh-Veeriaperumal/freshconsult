# encoding: utf-8
module Search::Job
  class << self
    include Redis::OthersRedis
    include Redis::RedisKeys

    def check_in_queue key
      result = get_others_redis_key(key)
      if result.nil?
        set_others_redis_key(key, true, 3600) # key expires in 60*60 seconds (1 HOUR)
        result = false
      end
      result
    end

    def remove_job_key key
      remove_others_redis_key key
    end

    def es_version
      (Time.zone.now.to_f * 1000000).ceil
    end
  end
end