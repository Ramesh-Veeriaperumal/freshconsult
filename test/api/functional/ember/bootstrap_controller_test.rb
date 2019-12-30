require_relative '../../test_helper'
class Ember::BootstrapControllerTest < ActionController::TestCase
  include BootstrapTestHelper
  include AgentsTestHelper
  include AttachmentsTestHelper
  include TrialSubscriptionHelper
  include Redis::RedisKeys
  include Redis::OthersRedis

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

  def test_me_for_ask_nicely_with_admin_privilege
    get :me, controller_params(version: 'private')
    assert_response 200
    email_hash = OpenSSL::HMAC.hexdigest('sha256', AskNicelyConfig['hash_token'], @agent.email)
    assert_equal response.api_meta[:asknicely_user_email_hash], email_hash
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

  def test_account_with_twitter_app_blocked
    set_others_redis_key(TWITTER_APP_BLOCKED, true, 1)
    get :account, controller_params(version: 'private')
    assert_response 200
    match_json(account_pattern(Account.current, Account.current.main_portal))
  ensure
    remove_others_redis_key TWITTER_APP_BLOCKED
  end

  def test_account_with_custom_inbox_error
    Account.current.stubs(:check_custom_mailbox_status).returns(true)
    get :account, controller_params(version: 'private')
    assert_response 200
    match_json(account_pattern(Account.current, Account.current.main_portal))
    Account.current.unstub(:check_custom_mailbox_status)  
  end

  def test_account_for_email_font_parameter
    AccountAdditionalSettings.any_instance.stubs(:additional_settings).returns({})
    get :account, controller_params(version: 'private')
    email_font = JSON.parse(response.body)['account']['email_fonts']
    assert email_font == DEFAULTS_FONT_SETTINGS[:email_template]

    AccountAdditionalSettings.any_instance.stubs(:additional_settings).returns(email_template: 'test')
    get :account, controller_params(version: 'private')
    email_font = JSON.parse(response.body)['account']['email_fonts']
    assert email_font == 'test'
    AccountAdditionalSettings.any_instance.unstub(:additional_settings)
  end

  def test_account_with_card_expiry_notification_agent
    User.current.stubs(:privilege?).with(:admin_tasks).returns(false)
    get :account, controller_params(version: 'private')
    assert_response 200
    match_json(account_pattern(Account.current, Account.current.main_portal))
    response = parse_response @response.body
    assert_equal response['config']['warnings']['card_expired'] , nil
    assert_equal response['config']['warnings']['next_renewal_date'] , nil
  ensure
    User.current.unstub(:privilege?)
  end

  def test_account_with_card_expiry_notification_display_banner_admin_card_expired
    User.current.stubs(:privilege?).with(:admin_tasks).returns(true)
    key = CARD_EXPIRY_KEY % { :account_id => Account.current.id }
    set_others_redis_hash(key,{ "next_renewal" => DateTime.now + 5.days, "card_expiry_date" => DateTime.now - 2.days})  
    get :account, controller_params(version: 'private')
    assert_response 200
    match_json(account_pattern(Account.current, Account.current.main_portal))
    response = parse_response @response.body
    assert_equal response['config']['warnings']['card_expired'] , true 
    assert_not_nil response['config']['warnings']['next_renewal_date']
  ensure
    remove_others_redis_key(key)
    User.current.unstub(:privilege?)
  end

  def test_account_with_card_expiry_notification_display_banner_admin_card_expiring
    User.current.stubs(:privilege?).with(:admin_tasks).returns(true)
    key = CARD_EXPIRY_KEY % { :account_id => Account.current.id }
    set_others_redis_hash(key,{ "next_renewal" => DateTime.now + 5.days, "card_expiry_date" => DateTime.now + 3.days}) 
    get :account, controller_params(version: 'private')
    assert_response 200
    match_json(account_pattern(Account.current, Account.current.main_portal))
    response = parse_response @response.body
    assert_equal response['config']['warnings']['card_expired'], false 
    assert_not_nil response['config']['warnings']['next_renewal_date']
  ensure
    remove_others_redis_key(key)
    User.current.unstub(:privilege?)
  end

  def test_account_with_card_expiry_notification_not_display_banner_admin
    User.current.stubs(:privilege?).with(:admin_tasks).returns(true)
    key = CARD_EXPIRY_KEY % { :account_id => Account.current.id }
    set_others_redis_hash(key,{ "next_renewal" => DateTime.now + 16.days, "card_expiry_date" => DateTime.now + 3.days})  
    get :account, controller_params(version: 'private')
    assert_response 200
    match_json(account_pattern(Account.current, Account.current.main_portal))
    response = parse_response @response.body
    assert_nil response['config']['warnings']['card_expired'] 
    assert_nil response['config']['warnings']['next_renewal_date'] 
  ensure
    remove_others_redis_key(key)
    User.current.unstub(:privilege?)
  end

  def test_account_with_card_expiry_notification_not_display_banner_admin_card_expire_after_next_renewal
    User.current.stubs(:privilege?).with(:admin_tasks).returns(true)
    key = CARD_EXPIRY_KEY % { :account_id => Account.current.id }
    set_others_redis_hash(key,{ "next_renewal" => DateTime.now + 5.days, "card_expiry_date" => DateTime.now + 8.days}) 
    get :account, controller_params(version: 'private')
    assert_response 200
    match_json(account_pattern(Account.current, Account.current.main_portal))
    response = parse_response @response.body
    assert_nil response['config']['warnings']['card_expiry_date'] 
    assert_nil response['config']['warnings']['next_renewal_date']
  ensure
    remove_others_redis_key(key)
    User.current.unstub(:privilege?)
  end

  def test_account_with_anonymous_key_present
    Account.any_instance.stubs(:anonymous_account?).returns(true)
    get :account, controller_params(version: 'private')
    assert_response 200
    match_json(account_pattern(Account.current, Account.current.main_portal))
  ensure
    Account.any_instance.unstub(:anonymous_account?)
  end

  def test_account_with_anonymous_key_not_present
    Account.any_instance.stubs(:anonymous_account?).returns(false)
    get :account, controller_params(version: 'private')
    assert_response 200
    match_json(account_pattern(Account.current, Account.current.main_portal))
  ensure
    Account.any_instance.unstub(:anonymous_account?)
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

  def test_invoice_due_warning_nil_for_admin
    set_user_privileges([:admin_tasks, :manage_users, :manage_tickets], [:manage_account])
    get :account, controller_params(version: 'private')
    assert_response 200
    match_json(account_pattern(Account.current, Account.current.main_portal))
    invoice = JSON.parse(response.body)['config']['warnings']['invoice_overdue']
    assert_nil invoice
  ensure
    User.any_instance.unstub(:privilege?)
  end

  def test_invoice_due_warning_with_skip_feature
    set_user_privileges([:admin_tasks, :manage_users, :manage_tickets], [:manage_account])
    Account.current.launch(:skip_invoice_due_warning)
    get :account, controller_params(version: 'private')
    assert_response 200
    match_json(account_pattern(Account.current, Account.current.main_portal))
    invoice = JSON.parse(response.body)['config']['warnings']['invoice_overdue']
    assert_nil invoice
  ensure
    User.any_instance.unstub(:privilege?)
    Account.current.rollback(:skip_invoice_due_warning)
  end


  def test_invoice_due_warning_with_skip_feature_with_redis_set
    set_user_privileges([:admin_tasks, :manage_users, :manage_tickets], [:manage_account])
    Account.current.launch(:skip_invoice_due_warning)
    set_others_redis_key(invoice_due_key, Time.now.utc.to_i - 10.days)
    get :account, controller_params(version: 'private')
    assert_response 200
    match_json(account_pattern(Account.current, Account.current.main_portal))
    invoice = JSON.parse(response.body)['config']['warnings']['invoice_overdue']
    assert_nil invoice
  ensure
    User.any_instance.unstub(:privilege?)
    Account.current.rollback(:skip_invoice_due_warning)
    remove_others_redis_key(invoice_due_key)
  end

  def test_invoice_due_warning_for_non_admin
    set_others_redis_key(invoice_due_key, Time.now.utc.to_i - 10.days)
    set_user_privileges([:manage_users, :manage_tickets], [:manage_account, :admin_tasks])
    get :account, controller_params(version: 'private')
    assert_response 200
    match_json(account_pattern(Account.current, Account.current.main_portal))
    invoice = JSON.parse(response.body)['config']['warnings']['invoice_overdue']
    assert_nil invoice
  ensure
    User.any_instance.unstub(:privilege?)
    remove_others_redis_key(invoice_due_key)
  end

  def test_invoice_due_warning_for_admin
    set_user_privileges([:admin_tasks, :manage_users, :manage_tickets], [:manage_account])
    invoice_key = format(INVOICE_DUE, account_id: Account.current.id)
    set_others_redis_key(invoice_due_key, Time.now.utc.to_i - 10.days)
    get :account, controller_params(version: 'private')
    assert_response 200
    match_json(account_pattern(Account.current, Account.current.main_portal))
    invoice = JSON.parse(response.body)['config']['warnings']['invoice_overdue']
    assert_equal invoice, false
  ensure
    User.any_instance.unstub(:privilege?)
    remove_others_redis_key(invoice_due_key)
  end

  def test_invoice_overdue_warning_for_admin
    set_user_privileges([:admin_tasks, :manage_users, :manage_tickets], [:manage_account])
    invoice_key = format(INVOICE_DUE, account_id: Account.current.id)
    set_others_redis_key(invoice_due_key, Time.now.utc.to_i - 20.days)
    get :account, controller_params(version: 'private')
    assert_response 200
    match_json(account_pattern(Account.current, Account.current.main_portal))
    invoice = JSON.parse(response.body)['config']['warnings']['invoice_overdue']
    assert_equal invoice, true
  ensure
    User.any_instance.unstub(:privilege?)
    remove_others_redis_key(invoice_due_key)
  end

  def test_invoice_email_for_non_account_admin
    set_user_privileges([:admin_tasks, :manage_users, :manage_tickets], [:manage_account])
    get :account, controller_params(version: 'private')
    assert_response 200
    match_json(account_pattern(Account.current, Account.current.main_portal))
    invoice = JSON.parse(response.body)['account']['subscription']['invoice_email']
    assert_nil invoice
  ensure
    User.any_instance.unstub(:privilege?)
  end

  def test_invoice_email_for_account_admin
    set_user_privileges([:manage_account, :admin_tasks, :manage_users, :manage_tickets], [])
    get :account, controller_params(version: 'private')
    assert_response 200
    match_json(account_pattern(Account.current, Account.current.main_portal))
    invoice = JSON.parse(response.body)['account']['subscription']['invoice_email']
    assert_not_nil invoice
  ensure
    User.any_instance.unstub(:privilege?)
  end

  def test_update_billing_info_for_non_account_admin
    Account.current.launch(:update_billing_info)
    set_user_privileges([:admin_tasks, :manage_users, :manage_tickets], [:manage_account])
    get :account, controller_params(version: 'private')
    assert_response 200
    match_json(account_pattern(Account.current, Account.current.main_portal))
    billing_update = JSON.parse(response.body)['config']['billing_info_update_enabled']
    assert_nil billing_update
  ensure
    User.any_instance.unstub(:privilege?)
    Account.current.rollback(:update_billing_info)
  end

  def test_update_billing_info_nil_for_account_admin
    set_user_privileges([:manage_account, :admin_tasks, :manage_users, :manage_tickets], [])
    get :account, controller_params(version: 'private')
    assert_response 200
    match_json(account_pattern(Account.current, Account.current.main_portal))
    billing_update = JSON.parse(response.body)['config']['billing_info_update_enabled']
    assert_nil billing_update
  ensure
    User.any_instance.unstub(:privilege?)
  end

  def test_update_billing_info_for_account_admin
    Account.current.launch(:update_billing_info)
    set_user_privileges([:manage_account, :admin_tasks, :manage_users, :manage_tickets], [])
    get :account, controller_params(version: 'private')
    assert_response 200
    match_json(account_pattern(Account.current, Account.current.main_portal))
    billing_update = JSON.parse(response.body)['config']['billing_info_update_enabled']
    assert_equal billing_update, true
  ensure
    User.any_instance.unstub(:privilege?)
    Account.current.rollback(:update_billing_info)
  end

  def test_account_with_field_service_management_enabled
    Account.any_instance.stubs(:field_service_management_enabled?).returns(true)
    Subscription.any_instance.stubs(:field_agent_limit).returns(5)
    get :account, controller_params(version: 'private')
    parsed_response = parse_response response.body
    assert_response 200
    assert_equal parsed_response['account']['subscription']['field_agent_limit'], 5
  ensure
    Subscription.unstub(:field_agent_limit)
    Account.unstub(:field_service_management_enabled?)
  end

  def test_account_with_field_service_management_not_enabled
    Account.any_instance.stubs(:field_service_management_enabled?).returns(false)
    get :account, controller_params(version: 'private')
    parsed_response = parse_response response.body
    assert_response 200
    assert_nil parsed_response['account']['subscription']['field_agent_limit']
  ensure
    Account.unstub(:field_service_management_enabled?)
  end

  def set_user_privileges(add_privileges, remove_privileges)
    add_privileges.each do |privilege|
      User.any_instance.stubs(:privilege?).with(privilege).returns(true)
    end
    remove_privileges.each do |privilege|
      User.any_instance.stubs(:privilege?).with(privilege).returns(false)
    end
  end

  def test_supress_logs_for_account_action
    Rails.env.stubs(:production?).returns(true)
    current_log_level = ActiveRecord::Base.logger.level
    get :account, controller_params(version: 'private')
    assert_response 200
    match_json(account_pattern(Account.current, Account.current.main_portal))
    assert_equal ActiveRecord::Base.logger.level, current_log_level
  ensure
    Rails.env.unstub(:production?)
  end

  def test_supress_logs_for_account_action_with_log_enabled_for_account
    Rails.env.stubs(:production?).returns(true)
    Account.current.launch(:disable_supress_logs)
    current_log_level = ActiveRecord::Base.logger.level
    get :account, controller_params(version: 'private')
    assert_response 200
    match_json(account_pattern(Account.current, Account.current.main_portal))
    assert_equal ActiveRecord::Base.logger.level, current_log_level
  ensure
    Rails.env.unstub(:production?)
    Account.current.rollback(:disable_supress_logs)
  end
end
