module CentralLib::CentralResyncRateLimiter
  include Redis::RedisKeys
  include Redis::OthersRedis
  include CentralLib::CentralResyncConstants

  def configure_redis_and_execute(source)
    key = resync_rate_limiter_key(source)
    set_and_increment_redis_key_on_job_start(key)
    yield
  ensure
    decrement_and_delete_redis_key_on_job_end(key)
  end

  def resync_worker_limit_reached?(source)
    current_worker_count_for_consumer(source) >= resync_worker_limit_per_consumer
  end

  def resync_ratelimit_options(args)
    {
      batch_size: get_max_allowed_records,
      run_after: RESYNC_RUN_AFTER,
      args: args,
      class_name: self.class.name
    }
  end

  private

  def set_and_increment_redis_key_on_job_start(key)
    set_others_redis_key_if_not_present(key, 0)
    increment_others_redis(key)
  end

  def decrement_and_delete_redis_key_on_job_end(key)
    decrement_others_redis(key)
  end

  def resync_worker_limit_per_consumer
    resync_worker_limit = get_others_redis_key(CENTRAL_RESYNC_MAX_ALLOWED_WORKERS)
    (resync_worker_limit && resync_worker_limit.to_i) || RESYNC_WORKER_LIMIT
  end

  def current_worker_count_for_consumer(source)
    current_running_workers = get_others_redis_key(resync_rate_limiter_key(source))
    (current_running_workers && current_running_workers.to_i) || 0
  end

  def get_max_allowed_records
    max_allowed_records = get_others_redis_key(CENTRAL_RESYNC_MAX_ALLOWED_RECORDS)
    (max_allowed_records && max_allowed_records.to_i) || RESYNC_MAX_ALLOWED_RECORDS
  end

  def resync_rate_limiter_key(source)
    format(CENTRAL_RESYNC_RATE_LIMIT, source: source)
  end
end
