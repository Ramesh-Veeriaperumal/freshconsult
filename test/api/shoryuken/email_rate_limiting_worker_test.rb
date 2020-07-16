require_relative '../test_helper'
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
require Rails.root.join('spec', 'support', 'agent_helper.rb')

class EmailRateLimitingWorkerTest < ActionView::TestCase
  include AccountTestHelper
  include EmailRateLimitTestHelper
  include EmailRateLimitHelper
  include AgentHelper
  include Redis::OthersRedis

  def setup
    @account = Account.first || create_test_account
    Account.stubs(:current).returns(@account)
  end

  def teardown
    Account.unstub(:current)
    super
  end

  def test_first_seven_rate_limit_exceeded_events_doesnot_trigger_banner
    time = Time.new(2020, 1, 1, 16, 1).to_i
    (0..6).each do |i|
      sqs_msg = Hashit.new(body: get_email_rate_limit_payload(time + i * 60).to_json)
      Ryuken::EmailRateLimitingWorker.new.perform(sqs_msg, nil)
    end
    email_rate_limit_count_key = rate_limit_count_key(@account.id, 16, 1)
    email_rate_limiting_breached_key = rate_limit_breached_key(@account.id)
    assert_equal 7.to_s, get_others_redis_key(email_rate_limit_count_key)
    assert_equal false, redis_key_exists?(email_rate_limiting_breached_key)
  ensure
    remove_others_redis_key(email_rate_limit_count_key)
    (1..7).each do |i|
      remove_others_redis_key(rate_limit_dedup_key(@account.id, i))
    end
  end

  def test_eighth_rate_limit_exceeded_event_triggers_banner
    Ryuken::EmailRateLimitingWorker.any_instance.stubs(:notify_admins_on_email_rate_limit_breach).returns(true)
    time = Time.new(2020, 1, 1, 16, 1).to_i
    (0..7).each do |i|
      sqs_msg = Hashit.new(body: get_email_rate_limit_payload(time + i * 60).to_json)
      Ryuken::EmailRateLimitingWorker.new.perform(sqs_msg, nil)
    end
    email_rate_limit_count_key = rate_limit_count_key(@account.id, 16, 1)
    email_rate_limiting_breached_key = rate_limit_breached_key(@account.id)
    email_rate_limiting_admin_notify_key = rate_limit_admin_notify_key(@account.id)
    expiry = 22.minutes
    assert_equal 8.to_s, get_others_redis_key(email_rate_limit_count_key)
    assert_equal 1.to_s, get_others_redis_key(email_rate_limiting_breached_key)
    assert_equal 1.to_s, get_others_redis_key(email_rate_limiting_admin_notify_key)
    assert_with_leeway expiry, get_others_redis_expiry(email_rate_limiting_breached_key)
  ensure
    Ryuken::EmailRateLimitingWorker.any_instance.unstub(:notify_admins_on_email_rate_limit_breach)
    remove_others_redis_key(email_rate_limit_count_key)
    remove_others_redis_key(email_rate_limiting_breached_key)
    remove_others_redis_key(email_rate_limiting_admin_notify_key)
    (1..8).each do |i|
      remove_others_redis_key(rate_limit_dedup_key(@account.id, i))
    end
  end

  def test_second_event_in_a_minute_is_discarded
    time = Time.new(2020, 1, 1, 16, 1).to_i
    sqs_msg = Hashit.new(body: get_email_rate_limit_payload(time).to_json)
    Ryuken::EmailRateLimitingWorker.new.perform(sqs_msg, nil)
    sqs_msg = Hashit.new(body: get_email_rate_limit_payload(time + 40.seconds).to_json)
    Ryuken::EmailRateLimitingWorker.new.perform(sqs_msg, nil)
    email_rate_limit_count_key = rate_limit_count_key(@account.id, 16, 1)
    assert_equal 1.to_s, get_others_redis_key(email_rate_limit_count_key)
  ensure
    remove_others_redis_key(email_rate_limit_count_key)
    remove_others_redis_key(rate_limit_dedup_key(@account.id, 1))
  end

  def test_event_in_second_quadrant_increases_expiry_breached_key
    Ryuken::EmailRateLimitingWorker.any_instance.stubs(:notify_admins_on_email_rate_limit_breach).returns(true)
    time = Time.new(2020, 1, 1, 16, 1).to_i
    (0..7).each do |i|
      sqs_msg = Hashit.new(body: get_email_rate_limit_payload(time + i * 60).to_json)
      Ryuken::EmailRateLimitingWorker.new.perform(sqs_msg, nil)
    end
    email_rate_limiting_breached_key = rate_limit_breached_key(@account.id)
    assert_equal get_others_redis_key(rate_limit_count_key(@account.id, 16, 1)), 8.to_s
    assert_with_leeway 22.minutes, get_others_redis_expiry(email_rate_limiting_breached_key)
    time = Time.new(2020, 1, 1, 16, 16).to_i
    sqs_msg = Hashit.new(body: get_email_rate_limit_payload(time).to_json)
    Ryuken::EmailRateLimitingWorker.new.perform(sqs_msg, nil)
    assert_equal 1.to_s, get_others_redis_key(rate_limit_count_key(@account.id, 16, 2))
    assert_with_leeway 29.minutes, get_others_redis_expiry(email_rate_limiting_breached_key)
  ensure
    Ryuken::EmailRateLimitingWorker.any_instance.unstub(:notify_admins_on_email_rate_limit_breach)
    remove_others_redis_key(rate_limit_count_key(@account.id, 16, 1))
    remove_others_redis_key(rate_limit_count_key(@account.id, 16, 2))
    remove_others_redis_key(email_rate_limiting_breached_key)
    remove_others_redis_key(rate_limit_admin_notify_key(@account.id))
    (1..8).each do |i|
      remove_others_redis_key(rate_limit_dedup_key(@account.id, i))
    end
    remove_others_redis_key(rate_limit_dedup_key(@account.id, 16))
  end

  def test_expiry_email_rate_limiting_count_key_quadrant_zeroth_min
    time = Time.new(2020, 1, 1, 16, 0, 0).to_i
    sqs_msg = Hashit.new(body: get_email_rate_limit_payload(time).to_json)
    Ryuken::EmailRateLimitingWorker.new.perform(sqs_msg, nil)
    email_rate_limit_count_key = rate_limit_count_key(@account.id, 16, 1)
    expiry = 30.minutes
    assert_with_leeway expiry, get_others_redis_expiry(email_rate_limit_count_key)
  ensure
    remove_others_redis_key(email_rate_limit_count_key)
    remove_others_redis_key(rate_limit_dedup_key(@account.id, 1))
  end

  def test_expiry_email_rate_limiting_count_key_quadrant_last_min
    time = Time.new(2020, 1, 1, 16, 14, 59).to_i
    sqs_msg = Hashit.new(body: get_email_rate_limit_payload(time).to_json)
    Ryuken::EmailRateLimitingWorker.new.perform(sqs_msg, nil)
    email_rate_limit_count_key = rate_limit_count_key(@account.id, 16, 1)
    expiry = 15.minutes + 1.second
    assert_with_leeway expiry, get_others_redis_expiry(email_rate_limit_count_key)
  ensure
    remove_others_redis_key(email_rate_limit_count_key)
    remove_others_redis_key(rate_limit_dedup_key(@account.id, 14))
  end

  def test_email_rate_limiting_worker_with_exception
    time = Time.new(2020, 1, 1, 16, 1).to_i
    sqs_msg = Hashit.new(body: get_email_rate_limit_payload(time).to_json)
    assert_nothing_raised do
      Ryuken::EmailRateLimitingWorker.any_instance.stubs(:process_email_rate_limiting).raises(RuntimeError)
      Ryuken::EmailRateLimitingWorker.new.perform(sqs_msg, nil)
    end
  ensure
    Ryuken::EmailRateLimitingWorker.any_instance.unstub(:process_email_rate_limiting)
  end

  def test_notify_admins_on_rate_limit_breach
    recipient1 = add_agent_to_account(@account, name: Faker::Name.name, active: 1, role: 1, language: 'en').user
    recipient2 = add_agent_to_account(@account, name: Faker::Name.name, active: 1, role: 1, language: 'de').user
    emails = [recipient1.email, recipient2.email]
    Account.any_instance.stubs(:fetch_all_admins_email).returns(emails)
    email_rate_limit_count_key = rate_limit_count_key(@account.id, 16, 1)
    set_others_redis_key(email_rate_limit_count_key, 7)
    time = Time.new(2020, 1, 1, 16, 8).to_i
    sqs_msg = Hashit.new(body: get_email_rate_limit_payload(time).to_json)
    response = Ryuken::EmailRateLimitingWorker.new.perform(sqs_msg, nil)
    assert_equal recipient1.email, response['en'].first
    assert_equal recipient2.email, response['de'].first
  ensure
    Account.any_instance.unstub(:fetch_all_admins_email)
    remove_others_redis_key(email_rate_limit_count_key)
    remove_others_redis_key(rate_limit_breached_key(@account.id))
    remove_others_redis_key(rate_limit_admin_notify_key(@account.id))
    remove_others_redis_key(rate_limit_dedup_key(@account.id, 8))
  end

  def test_expiry_for_admin_notify
    Ryuken::EmailRateLimitingWorker.any_instance.stubs(:notify_admins_on_email_rate_limit_breach).returns(true)
    email_rate_limit_count_key = rate_limit_count_key(@account.id, 16, 1)
    set_others_redis_key(email_rate_limit_count_key, 7)
    time = Time.new(2020, 1, 1, 16, 8).to_i
    sqs_msg = Hashit.new(body: get_email_rate_limit_payload(time).to_json)
    Ryuken::EmailRateLimitingWorker.new.perform(sqs_msg, nil)
    expiry = Helpdesk::Email::Constants::EMAIL_RATE_LIMIT_ADMIN_ALERT_EXPIRY
    email_rate_limiting_admin_notify_key = rate_limit_admin_notify_key(@account.id)
    assert_with_leeway expiry, get_others_redis_expiry(email_rate_limiting_admin_notify_key)
  ensure
    Ryuken::EmailRateLimitingWorker.any_instance.unstub(:notify_admins_on_email_rate_limit_breach)
    remove_others_redis_key(email_rate_limit_count_key)
    remove_others_redis_key(rate_limit_breached_key(@account.id))
    remove_others_redis_key(email_rate_limiting_admin_notify_key)
    remove_others_redis_key(rate_limit_dedup_key(@account.id, 8))
  end

  private

    def assert_with_leeway(expected, actual, leeway = 1)
      assert (expected - actual).abs <= leeway # the two values are within leeway
    end
end
