module TestSuiteMethods
  ES_ENABLED = false
  GNIP_ENABLED = false
  RIAK_ENABLED = false

  # DatabaseCleaner.clean_with(:truncation,
  #                            pre_count: true, reset_ids: false)
  $redis_others.flushall
end

include TestSuiteMethods
