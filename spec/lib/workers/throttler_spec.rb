require 'spec_helper'

SAMPLE_COUNT = "SAMPLE_COUNT:1"
THROTTLE_EVERY = 2.minutes.to_i
THROTTLE_LIMIT = 2 # affects the results
RETRY_DELAY = 4.minutes.to_i
WORKER_NAME = Workers::Webhook.to_s
WORKER_QUEUE = 'webhook_worker'
TEST_CASES = { # sequence is important, affects the results of the test cases
  :first_retry => { :test_case => { :worker => WORKER_NAME, :args => {}, :key => SAMPLE_COUNT, :expire_after => THROTTLE_EVERY, :limit => THROTTLE_LIMIT, :retry_after => RETRY_DELAY }, :verification_method => :verify_throttler_rescheduling },
  :first_webhook => { :test_case => { :worker => WORKER_NAME, :args => {}, :key => SAMPLE_COUNT, :expire_after => THROTTLE_EVERY, :limit => THROTTLE_LIMIT }, :verification_method => :verify_worker_enqueueing },
  
  :second_retry => { :test_case => { :worker => WORKER_NAME, :args => {}, :key => SAMPLE_COUNT, :expire_after => THROTTLE_EVERY, :limit => THROTTLE_LIMIT, :retry_after => RETRY_DELAY }, :verification_method => :verify_throttler_rescheduling },
  :second_webhook => { :test_case => { :worker => WORKER_NAME, :args => {}, :key => SAMPLE_COUNT, :expire_after => THROTTLE_EVERY, :limit => THROTTLE_LIMIT }, :verification_method => :verify_worker_enqueueing },

  :third_retry => { :test_case => { :worker => WORKER_NAME, :args => {}, :key => SAMPLE_COUNT, :expire_after => THROTTLE_EVERY, :limit => THROTTLE_LIMIT, :retry_after => RETRY_DELAY }, :verification_method => :verify_throttler_rescheduling },
  :third_webhook => { :test_case => { :worker => WORKER_NAME, :args => {}, :key => SAMPLE_COUNT, :expire_after => THROTTLE_EVERY, :limit => THROTTLE_LIMIT }, :verification_method => :verify_throttler_rescheduling }
}

RSpec.configure do |c|
  c.include Redis::RedisKeys
  c.include Redis::OthersRedis
end

RSpec.describe Workers::Throttler do

  before(:all) do
    Resque.inline = false
    remove_others_redis_key SAMPLE_COUNT
    remove_others_redis_key "resque:#{WORKER_QUEUE}"
    remove_others_redis_key "resque:delayed_queue_schedule"
  end

  TEST_CASES.each do |name, details|
    it "should #{name.to_s.humanize.downcase}" do
      send(details[:verification_method]) do
        Workers::Throttler.perform(details[:test_case])
      end
    end
  end

  def verify_worker_enqueueing
    before = Resque.size(WORKER_QUEUE)
    yield
    after = Resque.size(WORKER_QUEUE)
    (after - before).should be_eql(1)
  end

  def verify_throttler_rescheduling
    before = $redis_others.zcard("resque:delayed_queue_schedule") # Hack, No API to check the scheduler jobs
    yield
    sleep(1) # Resque.enqueue_in takes time to add the scheduler key
    after = $redis_others.zcard("resque:delayed_queue_schedule") # or $redis_others.keys("resque:delayed:*").size
    (after - before).should be_eql(1)
  end

end
