module BulkOperationsHelper
  include Redis::RedisKeys
  include Redis::OthersRedis

  BATCH_SIZE = 10_000
  RUN_AFTER = 120
  INDIVIDUAL_BATCH_SIZE = 300

  def rate_limit_options(args)
    {
      batch_size: batch_size,
      run_after: run_after,
      args: args,
      class_name: self.class.name
    }
  end

  private

    def individual_batch_size
      individual_batch_size_limit = get_others_redis_key(individual_batch_size_key)
      (individual_batch_size_limit && individual_batch_size_limit.to_i) || INDIVIDUAL_BATCH_SIZE
    end

    def batch_size
      batch_size = get_others_redis_key(batch_size_key)
      (batch_size && batch_size.to_i) || BATCH_SIZE
    end

    def run_after
      next_run_at = get_others_redis_key(run_after_key)
      (next_run_at && next_run_at.to_i.seconds) || RUN_AFTER.seconds
    end

    def individual_batch_size_key
      format(INDIVIDUAL_BATCH_SIZE_KEY, class_name: self.class.name)
    end

    def batch_size_key
      format(BULK_OPERATIONS_RATE_LIMIT_BATCH_SIZE, class_name: self.class.name)
    end

    def run_after_key
      format(BULK_OPERATIONS_RATE_LIMIT_NEXT_RUN_AT, class_name: self.class.name)
    end
end
