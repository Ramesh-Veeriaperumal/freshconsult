require Rails.root.join("test/test_file_methods.rb")
module TestSuiteMethods
  ES_ENABLED = false
  GNIP_ENABLED = false
  RIAK_ENABLED = false

  if !defined?($clean_db) || $clean_db == true
    DatabaseCleaner.clean_with(:truncation,
                             pre_count: true, reset_ids: false)
  end
  $redis_others.flushall
end

include TestSuiteMethods
