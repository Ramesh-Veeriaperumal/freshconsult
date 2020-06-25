require_relative '../test_helper'
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')

class EmailRateLimitingWorkerTest < ActionView::TestCase
  include AccountTestHelper
  include EmailRateLimitTestHelper
  include EmailRateLimitHelper
  include Redis::OthersRedis

  def setup
    @account = Account.first || create_test_account
    Account.stubs(:current).returns(@account)
    @time_now = Time.now.in_time_zone
    Time.stubs(:now).returns(@time_now)
    @sqs_msg = Hashit.new(body: get_email_rate_limit_payload.to_json)
  end

  def teardown
    Account.unstub(:current)
    Time.unstub(:now)
    super
  end

  def test_set_email_rate_limiting_count_key
    Ryuken::EmailRateLimitingWorker.new.perform(@sqs_msg, nil)
    email_rate_limit_count_key = rate_limit_count_key(@account.id, @time_now.hour, @time_now.min / 15 + 1)
    assert_equal get_others_redis_key(email_rate_limit_count_key), 1.to_s
  ensure
    remove_others_redis_key(email_rate_limit_count_key)
  end

  def test_incr_email_rate_limiting_count_key
    email_rate_limit_count_key = rate_limit_count_key(@account.id, @time_now.hour, @time_now.min / 15 + 1)
    set_others_redis_key(email_rate_limit_count_key, 4)
    Ryuken::EmailRateLimitingWorker.new.perform(@sqs_msg, nil)
    assert_equal get_others_redis_key(email_rate_limit_count_key), 5.to_s
  ensure
    remove_others_redis_key(email_rate_limit_count_key)
  end

  def test_set_email_rate_limiting_breached_key
    Ryuken::EmailRateLimitingWorker.any_instance.stubs(:increment_others_redis).returns(9)
    Ryuken::EmailRateLimitingWorker.new.perform(@sqs_msg, nil)
    email_rate_limiting_count_key = rate_limit_count_key(@account.id, @time_now.hour, @time_now.min / 15 + 1)
    email_rate_limiting_breached_key = rate_limit_breached_key(@account.id)
    assert_equal get_others_redis_key(email_rate_limiting_breached_key), 1.to_s
  ensure
    Ryuken::EmailRateLimitingWorker.any_instance.unstub(:increment_others_redis)
    remove_others_redis_key(email_rate_limiting_count_key)
    remove_others_redis_key(email_rate_limiting_breached_key)
  end

  def test_existence_email_rate_limiting_breached_key_when_not_rate_limited
    Ryuken::EmailRateLimitingWorker.any_instance.stubs(:increment_others_redis).returns(2)
    email_rate_limiting_breached_key = rate_limit_breached_key(@account.id)
    Ryuken::EmailRateLimitingWorker.new.perform(@sqs_msg, nil)
    assert_equal false, redis_key_exists?(email_rate_limiting_breached_key)
  ensure
    Ryuken::EmailRateLimitingWorker.any_instance.unstub(:increment_others_redis)
    remove_others_redis_key(rate_limit_count_key(@account.id, @time_now.hour, @time_now.min / 15))
  end

  def test_expiry_email_rate_limiting_breached_key
    Ryuken::EmailRateLimitingWorker.any_instance.stubs(:increment_others_redis).returns(2)
    email_rate_limiting_breached_key = rate_limit_breached_key(@account.id)
    set_others_redis_key(email_rate_limiting_breached_key, 1)
    Ryuken::EmailRateLimitingWorker.new.perform(@sqs_msg, nil)
    quadrant = @time_now.min / 15 + 1
    expiry = 15 * (1 + quadrant) * 60 - (@time_now.min * 60 + @time_now.sec)
    assert_equal get_others_redis_key(email_rate_limiting_breached_key), 1.to_s
    assert_equal expiry, get_others_redis_expiry(email_rate_limiting_breached_key)
  ensure
    Ryuken::EmailRateLimitingWorker.any_instance.unstub(:increment_others_redis)
    remove_others_redis_key(rate_limit_count_key(@account.id, @time_now.hour, @time_now.min / 15))
    remove_others_redis_key(email_rate_limiting_breached_key)
  end

  def test_email_rate_limiting_worker_with_exception
    assert_nothing_raised do
      Ryuken::EmailRateLimitingWorker.any_instance.stubs(:increment_others_redis).raises(RuntimeError)
      Ryuken::EmailRateLimitingWorker.new.perform(@sqs_msg, nil)
    end
  ensure
    Ryuken::EmailRateLimitingWorker.any_instance.unstub(:increment_others_redis)
  end
end
