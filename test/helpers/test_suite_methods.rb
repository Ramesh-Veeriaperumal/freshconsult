module TestSuiteMethods
  ES_ENABLED = false
  GNIP_ENABLED = false
  RIAK_ENABLED = false

  DatabaseCleaner.clean_with(:truncation,
                                   {:pre_count => true, :reset_ids => false})

  Minitest::Reporters.use! [Minitest::Reporters::SpecReporter.new, Minitest::Reporters::JUnitReporter.new]
  $redis_others.flushall
end

include TestSuiteMethods