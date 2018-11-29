require_relative '../../test_helper'
class Ember::BootstrapControllerTest < ActionController::TestCase
  include BootstrapTestHelper
  include AgentsTestHelper
  include AttachmentsTestHelper
  include TrialSubscriptionHelper
  
  def setup 
    super
    @subscription_plan = SubscriptionPlan.last
  end

  def test_index
    get :index, controller_params(version: 'private')
    assert_response 200
    match_json(index_pattern(@agent.agent, Account.current, Account.current.portals.first))
  end

  def test_me
    get :me, controller_params(version: 'private')
    assert_response 200
    match_json(agent_info_pattern(@agent.agent))
  end

  def test_account
    get :account, controller_params(version: 'private')
    assert_response 200
    match_json(account_pattern(Account.current, Account.current.main_portal))
  end

  def test_account_without_admin_and_accout_admin_privilege
    User.any_instance.stubs(:privilege?).with(:admin_tasks).returns(false)
    User.any_instance.stubs(:privilege?).with(:manage_account).returns(false)
    User.any_instance.stubs(:privilege?).with(:manage_tickets).returns(true)
    get :account, controller_params(version: 'private')
    parsed_response = parse_response response.body
    assert_response 200
    assert_nil parsed_response['account']['subscription']['mrr']
    assert_nil parsed_response['config']['growthscore_app_id']
  ensure
    User.any_instance.unstub(:privilege?)
  end

  def test_account_with_fav_icon_for_portal
    portal = Account.current.main_portal
    file = fixture_file_upload('/files/image33kb.jpg', 'image/jpg')
    fav_icon = create_attachment(content: file, attachable_type: 'Portal', attachable_id: portal.id, description: 'fav_icon')
    get :account, controller_params(version: 'private')
    assert_response 200
    match_json(account_pattern(Account.current, portal))
  end

  def test_iris_key
    get :index, controller_params(version: 'private')
    agent_info = ActiveSupport::JSON.decode(response.body)['agent']
    assert_not_nil response.api_meta[:iris_notification_url]
  end

  def test_marketplace_auth_token
    get :index, controller_params(version: 'private')
    agent_info = ActiveSupport::JSON.decode(response.body)['agent']
    assert_not_nil response.api_meta[:marketplace_auth_token]
  end

  def test_collision_autorefresh_freshid_keys
    Account.current.features.collision.create
    Account.current.add_feature(:auto_refresh)
    Account.current.launch(:freshid)
    Account.current.reload
    get :index, controller_params(version: 'private')
    agent_info = ActiveSupport::JSON.decode(response.body)['agent']
    assert_not_nil response.api_meta[:collision_url]
    assert_not_nil response.api_meta[:autorefresh_url]
    assert_not_nil response.api_meta[:freshid_url]
    assert_not_nil response.api_meta[:freshid_profile_url]
    assert_not_nil agent_info['autorefresh_user_hash']
    assert_not_nil agent_info['collision_user_hash']

    Account.current.features.collision.destroy
    Account.current.rollback(:freshid)
    Account.current.revoke_feature(:auto_refresh)
    Account.current.reload
    get :index, controller_params(version: 'private')
    agent_info = ActiveSupport::JSON.decode(response.body)['agent']
    assert_nil response.api_meta[:collision_url]
    assert_nil response.api_meta[:autorefresh_url]
    assert_nil response.api_meta[:freshid_url]
    assert_nil response.api_meta[:freshid_profile_url]
    assert_nil agent_info['autorefresh_user_hash']
    assert_nil agent_info['collision_user_hash']
  end

  def test_custom_dashboard_limits_without_feature
    Account.current.stubs(:custom_dashboard_enabled?).returns(false)
    get :account, controller_params(version: 'private')
    assert_response 200
    match_json(account_pattern(Account.current, Account.current.main_portal))
  end

  def test_custom_dashboard_limits_with_feature
    Account.current.stubs(:custom_dashboard_enabled?).returns(true)
    get :account, controller_params(version: 'private')
    assert_response 200
    match_json(account_pattern(Account.current, Account.current.main_portal))
  end

  def test_account_with_trial_subscription
    trial_subscription = create_trail_subscription(user_id: @agent.id,
      trial_plan: @subscription_plan.name)
    get :account, controller_params(version: 'private')
    assert_response 200
    match_json(account_with_trial_subscription_pattern(Account.current, 
      Account.current.main_portal, trial_subscription, @subscription_plan))
    Account.current.trial_subscriptions.destroy_all
  end
  
  def test_account_with_recent_trial_subscription
    create_trail_subscription(user_id: @agent.id, status: 2)
    trial_subscription = create_trail_subscription(user_id: @agent.id, 
      trial_plan: @subscription_plan.name)
    get :account, controller_params(version: 'private')
    assert_response 200
    match_json(account_with_trial_subscription_pattern(Account.current, 
      Account.current.main_portal, trial_subscription, @subscription_plan))
    Account.current.trial_subscriptions.destroy_all
  end
  
  def test_cancelled_trial_subscription
    create_trail_subscription(user_id: @agent.id, status: 2)
    trial_subscription = create_trail_subscription(user_id: @agent.id,
      trial_plan: @subscription_plan.name)
    get :account, controller_params(version: 'private')
    assert_response 200
    match_json(account_with_trial_subscription_pattern(Account.current, 
      Account.current.main_portal, trial_subscription, @subscription_plan))
    Account.current.trial_subscriptions.destroy_all
  end

  def test_account_with_facebook_reauth_required
    Account.current.stubs(:fb_reauth_check_from_cache).returns(true)
    get :account, controller_params(version: 'private')
    assert_response 200
    match_json(account_pattern(Account.current, Account.current.main_portal))
    Account.current.unstub(:fb_reauth_check_from_cache)
  end 

  def test_account_with_twitter_reauth_required
    Account.current.stubs(:twitter_reauth_check_from_cache).returns(true)
    get :account, controller_params(version: 'private')
    assert_response 200
    match_json(account_pattern(Account.current, Account.current.main_portal))
    Account.current.unstub(:twitter_reauth_check_from_cache)
  end

  def test_account_with_custom_inbox_error
    Account.current.stubs(:check_custom_mailbox_status).returns(true)
    get :account, controller_params(version: 'private')
    assert_response 200
    match_json(account_pattern(Account.current, Account.current.main_portal))
    Account.current.unstub(:check_custom_mailbox_status)  
  end 
  
  def test_collaboration_without_freshconnect
    Account.any_instance.stubs(:collaboration_enabled?).returns(true)
    Account.current.add_feature(:collaboration)
    Account.current.reload
    get :account, controller_params(version: 'private')
    assert_response 200
    match_json(account_pattern(Account.current, Account.current.main_portal))
  end

  def test_freshconnect_without_collaboration
    User.current.authorizations.build(provider: Freshid::Constants::FRESHID_PROVIDER, uid: freshid_user.uuid)
    Account.current.revoke_feature(:collaboration)
    Account.any_instance.stubs(:freshconnect_enabled?).returns(true)
    Account.current.add_feature(:freshconnect)
    Account.current.launch(:freshid)
    Account.current.reload
    get :account, controller_params(version: 'private')
    assert_response 200
    match_json(account_pattern(Account.current, Account.current.main_portal))
    Account.current.revoke_feature(:freshconnect)
    Account.current.rollback(:freshid)
  end

end
