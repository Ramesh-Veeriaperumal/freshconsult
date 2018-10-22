require Rails.root.join("test/test_file_methods.rb")
module TestSuiteMethods
  ES_ENABLED = false
  GNIP_ENABLED = false
  RIAK_ENABLED = false

  # Sharding.run_on_all_shards do
  DatabaseCleaner.clean_with(:truncation,
                             pre_count: true, reset_ids: false)
  #   set_autoincrement_ids
  # end
  $redis_others.flushall
end

include TestSuiteMethods
