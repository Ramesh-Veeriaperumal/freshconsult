require_relative '../../test_helper.rb'
require 'sidekiq/testing'
Sidekiq::Testing.fake!

class Admin::TrialSubscriptionsControllerTest < ActionController::TestCase
  def setup
    super
    before_all
  end

  def before_all
    TrialSubscription.all.each(&:delete)
    Account.current.launch TrialSubscription::TRIAL_SUBSCRIPTION_LP_FEATURE
    subscription = Account.current.subscription
    if subscription.trial?
      subscription.state = Subscription::ACTIVE
      subscription.save!
    end
  end

  def wrap_cname(params_hash)
    { trial_subscription: params_hash }
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
end
