require_relative '../../test_helper.rb'
require 'sidekiq/testing'
Sidekiq::Testing.fake!

class Admin::TrialSubscriptionsControllerTest < ActionController::TestCase
  include Redis::RateLimitRedis
  def setup
    super
    before_all
  end

  def before_all
    TrialSubscription.all.each(&:delete)
    Account.current.launch TrialSubscription::TRIAL_SUBSCRIPTION_LP_FEATURE
    Account.current.rollback(:downgrade_policy)
    subscription = Account.current.subscription
    if subscription.trial?
      subscription.state = Subscription::ACTIVE
      subscription.save!
    end

    plan_api_rate_limits = {
      "Sprout Jan 19": 0,
      "Blossom Jan 19": 3000,
      "Garden Jan 19": 3000,
      "Estate Jan 19": 5000,
      "Forest Jan 19": 5000,
      "Garden Omni Jan 19": 3000,
      "Estate Omni Jan 19": 5000
    }

    SubscriptionPlan.select([:id, :name]).each do |sp|
      limit = plan_api_rate_limits[sp.name.to_sym]
      $rate_limit.perform_redis_op("set", "PLAN_API_LIMIT:#{sp.id}", limit) if limit.present?
    end
  end

  def wrap_cname(params_hash)
    { trial_subscription: params_hash }
  end

  def account_api_limit_key
    ACCOUNT_API_LIMIT % { account_id: Account.current.id }
  end

  def find_plan_by_name(plan_name)
    SubscriptionPlan.cached_current_plans.find { |plan| plan.name == plan_name }
  end

  def get_valid_plan_name
    valid_plan_names = SubscriptionPlan.current_plan_names_from_cache
    valid_plan_names[rand(valid_plan_names.length)]
  end

  def get_invalid_plan_name
    Faker::Lorem.word
  end

  def test_create_with_valid_plan_name
    params_hash = { trial_plan: get_valid_plan_name }
    post :create, construct_params({}, params_hash)
    assert_response 204
  end

  def test_create_with_old_plan_name
    params_hash = { trial_plan: get_invalid_plan_name }
    post :create, construct_params({}, params_hash)
    assert_response 400
  end

  def test_create_with_invalid_plan_name
    params_hash = { trial_plan: Faker::Lorem.word }
    post :create, construct_params({}, params_hash)
    assert_response 400
  end

  def test_create_with_existing_trial_subscription
    params_hash = { trial_plan: get_valid_plan_name }
    post :create, construct_params({}, params_hash)
    assert_response 204
    post :create, construct_params({}, params_hash)
    assert_response 400
  end

  def test_create_with_no_plan_name
    params_hash = {}
    post :create, construct_params({}, params_hash)
    assert_response 400
    params_hash = { trial_plan: '' }
    post :create, construct_params({}, params_hash)
    assert_response 400
    params_hash = { trial_plan: nil }
    post :create, construct_params({}, params_hash)
    assert_response 400
  end

  def test_trial_subscription_creation
    params_hash = { trial_plan: get_valid_plan_name }
    post :create, construct_params({}, params_hash)
    assert_response 204
  end

  def test_create_when_scheduled_subscription_is_present_in_chargebee
    subscription_request = SubscriptionRequest.new(
      account_id: @account.id,
      agent_limit: 1,
      plan_id: SubscriptionPlan.current.map(&:id).third,
      renewal_period: 1,
      subscription_id: @account.subscription.id
    )
    subscription_request.save!
    ChargeBee::Subscription.stubs(:remove_scheduled_changes).returns(true)
    params_hash = { trial_plan: get_valid_plan_name }
    post :create, construct_params({}, params_hash)
    assert_response 204
  ensure
    ChargeBee::Subscription.unstub(:remove_scheduled_changes)
    Account.current.subscription.subscription_request.destroy if @account.subscription.subscription_request.present?
  end

  def test_create_when_scheduled_subscription_not_present_in_chargebee
    subscription_request = SubscriptionRequest.new(
      account_id: @account.id,
      agent_limit: 1,
      plan_id: SubscriptionPlan.current.map(&:id).third,
      renewal_period: 1,
      subscription_id: @account.subscription.id
    )
    subscription_request.save!
    invalid_request_json = { message: 'id: The value chargebee_account is already present.', type: 'invalid_request', api_error_code: 'duplicate_entry', param: 'id', error_code: 'no_scheduled_changes', error_msg: 'The value chargebee_account is already present.', error_param: 'id', http_status_code: 400 }
    chargebee_error = ChargeBee::InvalidRequestError.new(200, invalid_request_json)
    ChargeBee::Subscription.stubs(:remove_scheduled_changes).raises(chargebee_error)
    params_hash = { trial_plan: get_valid_plan_name }
    post :create, construct_params({}, params_hash)
    assert_response 204
  ensure
    ChargeBee::Subscription.unstub(:remove_scheduled_changes)
    Account.current.subscription.subscription_request.destroy if @account.subscription.subscription_request.present?
  end

  def test_create_when_chargebee_rises_error
    @account = Account.current
    subscription_request = SubscriptionRequest.new(
      account_id: @account.id,
      agent_limit: 1,
      plan_id: SubscriptionPlan.current.map(&:id).third,
      renewal_period: 1,
      subscription_id: @account.subscription.id
    )
    @account.launch :downgrade_policy
    subscription_request.save!
    invalid_request_json = { message: 'id: The value chargebee_account is already present.', type: 'invalid_request', api_error_code: 'duplicate_entry', param: 'id', error_code: 'param_not_unique', error_msg: 'The value chargebee_account is already present.', error_param: 'id', http_status_code: 400 }
    chargebee_error = ChargeBee::InvalidRequestError.new(400, invalid_request_json)
    ChargeBee::Subscription.stubs(:remove_scheduled_changes).raises(chargebee_error)
    params_hash = { trial_plan: get_valid_plan_name }
    assert_raise(ChargeBee::InvalidRequestError) { post :create, construct_params({}, params_hash) }
  ensure
    ChargeBee::Subscription.unstub(:remove_scheduled_changes)
    Account.current.subscription.subscription_request.destroy if @account.subscription.subscription_request.present?
  end

  def test_create_when_scheduled_cancellation_is_present_in_chargebee
    @account.launch :downgrade_policy
    set_others_redis_key(@account.account_cancellation_request_time_key, Time.zone.now)
    ChargeBee::Subscription.stubs(:remove_scheduled_cancellation).returns(true)
    params_hash = { trial_plan: get_valid_plan_name }
    post :create, construct_params({}, params_hash)
    assert_response 204
    refute @account.account_cancellation_requested_time
  ensure
    @account.rollback :downgrade_policy
    remove_others_redis_key(@account.account_cancellation_request_time_key)
    ChargeBee::Subscription.unstub(:remove_scheduled_cancellation)
  end

  def test_create_when_scheduled_cancellation_not_present_in_chargebee
    @account = Account.current
    @account.launch :downgrade_policy
    set_others_redis_key(@account.account_cancellation_request_time_key, Time.zone.now)
    ChargeBee::Subscription.stubs(:remove_scheduled_cancellation).raises(ChargeBee::InvalidRequestError)
    params_hash = { trial_plan: get_valid_plan_name }
    post :create, construct_params({}, params_hash)
    assert_response 400
    match_json([{ 'code' => 'invalid_value', 'field' => :base, 'message' => 'Error while removing account cancellation request!' }])
  ensure
    @account.rollback :downgrade_policy
    remove_others_redis_key(@account.account_cancellation_request_time_key)
    ChargeBee::Subscription.unstub(:remove_scheduled_cancellation)
  end

  def test_latest_trial_subscription_ends_at
    t = TrialSubscription.new(
      ends_at: Time.now.utc - TrialSubscription::TRIAL_INTERVAL_IN_DAYS.days / 2,
      from_plan: get_valid_plan_name,
      trial_plan: get_valid_plan_name,
      account_id: Account.current.id,
      actor_id: Account.current.account_managers.first.id,
      status: TrialSubscription::TRIAL_STATUSES[:cancelled]
    )
    t.save!
    params_hash = { trial_plan: get_valid_plan_name }
    post :create, construct_params({}, params_hash)
    assert_response 400

    t.ends_at -= TrialSubscription::TRIAL_INTERVAL_IN_DAYS.days
    t.save!
    params_hash = { trial_plan: get_valid_plan_name }
    post :create, construct_params({}, params_hash)
    assert_response 204
  end

  def test_400_while_creating_trial_within_interval_period
    params_hash = { trial_plan: get_valid_plan_name }
    post :create, construct_params({}, params_hash)
    assert_response 204

    t = Account.current.trial_subscriptions.last
    t.status = 1
    t.ends_at -= TrialSubscription::TRIAL_INTERVAL_IN_DAYS.days
    t.save!

    params_hash = { trial_plan: get_valid_plan_name }
    post :create, construct_params({}, params_hash)
    assert_response 400
  end

  def test_latest_trial_subscription_with_no_privilege
    User.any_instance.stubs(:privilege?).with(:manage_account).returns(false)
    params_hash = { trial_plan: get_valid_plan_name }
    post :create, construct_params({}, params_hash)
    assert_response 403
  end

  def test_trial_subscription_cancellation
    params_hash = { trial_plan: get_valid_plan_name }
    post :create, construct_params({}, params_hash)
    assert_response 204
    put :cancel, construct_params({})
    assert_response 204
  end

  def test_trial_subscription_cancellation_end_at
    params_hash = { trial_plan: get_valid_plan_name }
    post :create, construct_params({}, params_hash)
    assert_response 204
    put :cancel, construct_params({})
    trial_subscription = Account.current.trial_subscriptions.last
    assert_equal TrialSubscription::TRIAL_INTERVAL_IN_DAYS, trial_subscription.days_left_until_next_trial,
                 'Trail should be 90 days when cancelled'
  end

  def test_trial_subscription_cancellation_failure
    put :cancel, construct_params({})
    assert_response 400
  end

  def test_trial_subscription_cancellation_with_no_privilege
    params_hash = { trial_plan: get_valid_plan_name }
    post :create, construct_params({}, params_hash)
    assert_response 204
    User.any_instance.stubs(:privilege?).with(:manage_account).returns(false)
    put :cancel, construct_params({})
    assert_response 403
  end

  def test_trial_subscription_api_without_lp_feature
    Account.current.rollback TrialSubscription::TRIAL_SUBSCRIPTION_LP_FEATURE
    params_hash = { trial_plan: get_valid_plan_name }
    post :create, construct_params({}, params_hash)
    assert_response 403
  end

  def test_usage_metrics
    features = ['skill_based_round_robin', 'email_notification', 'custom_dashboard']
    get :usage_metrics, controller_params(version: 'private', 
      features: features.join(','))
    assert_response 200
    data = JSON.parse(response.body)
    assert_equal 3, data.count
    data.keys.all?{ |key| features.include? key }
    data.values.each{ |result| assert_include [true, false], result }  
  end

  def test_usage_metrics_for_all_features
    list = UsageMetrics::Features::FEATURES_LIST + 
      UsageMetrics::Features::FEATURES_TRUE_BY_DEFAULT
    shard = ShardMapping.lookup_with_account_id(Account.current.id)
    result_array = UsageMetrics::Features.metrics(Account.current, shard, list)
    result_array.values.each{ |result| assert_include [true, false], result }
    result_array.keys.each{ |result| assert_include list, result }
  end

  def test_extending_the_trial_period
    params_hash = { trial_plan: get_valid_plan_name }
    post :create, construct_params({}, params_hash)
    assert_response 204
    account = Account.current
    account.active_trial.extend_trial(10)
    assert_equal(10.days.from_now.end_of_day.to_i, account.reload.active_trial.ends_at.to_i)
  end

  def test_set_expiry_api_limit_on_extend_trial
    set_account_api_limit(3000)
    set_redis_expiry(account_api_limit_key, 1829361)
    trial_plan_name = get_valid_plan_name
    params_hash = { trial_plan: trial_plan_name }
    post :create, construct_params({}, params_hash)
    assert_response 204
    account = Account.current
    account.active_trial.extend_trial(10)
    assert_equal(10.days.from_now.end_of_day.to_i, account.reload.active_trial.ends_at.to_i)
    assert_equal (get_redis_api_expiry(account_api_limit_key) / 86400).round, 10
  end

  def test_setnot_expiry_api_limit_on_extend_trial
    set_account_api_limit(3000)
    set_redis_expiry(account_api_limit_key, 1829361)
    trial_plan_name = get_valid_plan_name
    params_hash = { trial_plan: trial_plan_name }
    post :create, construct_params({}, params_hash)
    assert_response 204
    set_account_api_limit(0)
    account = Account.current
    account.active_trial.extend_trial(10)
    assert_equal(10.days.from_now.end_of_day.to_i, account.reload.active_trial.ends_at.to_i)
    assert_equal (get_redis_api_expiry(account_api_limit_key) / 86400).round, -1
  end

  def test_set_expiry_api_limit_on_trial_with_redis_key_absence
    set_account_api_limit(nil)
    trial_plan = get_valid_plan_name
    plan_key = format(PLAN_API_LIMIT, plan_id: find_plan_by_name(trial_plan).id)
    params_hash = { trial_plan: trial_plan }
    post :create, construct_params({}, params_hash)
    assert_response 204
    assert_equal get_account_api_limit, get_api_rate_limit(plan_key)
    assert_equal (get_redis_api_expiry(account_api_limit_key) / 86400).round, Subscription::TRIAL_DAYS
  end

  def test_set_expiry_api_limit_with_redis_key_and_ttl_presence
    set_account_api_limit(3000)
    set_redis_expiry(account_api_limit_key, 1829361)
    trial_plan_name = get_valid_plan_name
    plan_key = format(PLAN_API_LIMIT, plan_id: find_plan_by_name(trial_plan_name).id)
    params_hash = { trial_plan: trial_plan_name }
    post :create, construct_params({}, params_hash)
    assert_response 204
    assert_equal get_account_api_limit, get_api_rate_limit(plan_key)
    assert_equal (get_redis_api_expiry(account_api_limit_key) / 86400).round, Subscription::TRIAL_DAYS
  end

  def test_set_api_limit_with_redis_key_presence_and_ttl_absence
    set_account_api_limit(3000)
    post :create, construct_params({}, trial_plan: get_valid_plan_name)
    assert_response 204
    assert_equal get_account_api_limit, "3000"
  end

  def test_remove_account_api_limit_on_cancel_with_ttl_presence
    set_account_api_limit(nil)
    params_hash = { trial_plan: get_valid_plan_name }
    post :create, construct_params({}, params_hash)
    assert_response 204
    put :cancel, construct_params({})
    assert_response 204
    assert_equal get_account_api_limit, nil
  end

  def test_setnot_account_api_limit_on_cancel_with_ttl_absence
    set_account_api_limit(nil)
    trial_plan_name = get_valid_plan_name
    plan_key = format(PLAN_API_LIMIT, plan_id: find_plan_by_name(trial_plan_name).id)
    params_hash = { trial_plan: trial_plan_name }
    post :create, construct_params({}, params_hash)
    assert_response 204
    set_redis_expiry(account_api_limit_key, 0)
    set_account_api_limit(get_api_rate_limit(plan_key))
    put :cancel, construct_params({})
    assert_response 204
    assert_equal get_account_api_limit, get_api_rate_limit(plan_key)
  end
end
