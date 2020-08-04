require_relative '../unit_test_helper'
require_relative '../test_helper'
require 'sidekiq/testing'
require Rails.root.join('spec', 'support', 'account_helper.rb')

class AccountTest < ActionView::TestCase
  include AccountHelper
  include UsersTestHelper

  def setup
    super
    before_all
  end

  @@before_all_run = false

  def before_all
    return if @@before_all_run
    @account = create_test_account
    supported_languages = pick_languages(@account.language, 3)
    @account.account_additional_settings.update_attributes(:supported_languages => supported_languages)
    @account.account_additional_settings.update_attributes(:additional_settings => { :portal_languages => supported_languages.sample(2) })
    @account.features.enable_multilingual.create unless @account.features?(:enable_multilingual)
    Account.stubs(:first).returns(Account.current)
    @@before_all_run = true
  end

  def teardown
    super
  end

  def subscription
    Account.current.subscription
  end

  def agent_types
    Account.current.agent_types
  end

  def account_additional_settings
    Account.current.account_additional_settings
  end

  def contact_form
    Account.current.contact_form
  end

  def company_form
    Account.current.company_form
  end

  def id
    1
  end

  def account_cancel_request_job_key
    1
  end

  def test_domain_valid
    account = Account.new(domain: "test-1234", name: "Test Account")
    account.time_zone = "Chennai"
    plan = Account.current.plan
    account.plan = plan
    assert account.valid?
  end

  def test_domain_start_with_hyphen_invalid
    account = Account.new(domain: "-test1234")
    account.plan = Account.current.plan
    refute account.valid?
    errors = account.errors.full_messages
    assert errors.include?('Domain is invalid')
  end

  def test_domain_end_with_hyphen_invalid
    account = Account.new(domain: "test1234-")
    account.plan = Account.current.plan
    refute account.valid?
    errors = account.errors.full_messages
    assert errors.include?('Domain is invalid')
  end

  def test_domain_with_special_characters_invalid
    account = Account.new(domain: "test*1234")
    account.plan = Account.current.plan
    refute account.valid?
    errors = account.errors.full_messages
    assert errors.include?('Domain is invalid')
  end

  def test_group_type_mapping
    account = Account.current
    mapping = account.group_types.new(name: 'support_agent_group', group_type_id: 1, label: 'support_agent_group')
    Account.any_instance.stubs(:group_types_from_cache).returns([mapping])
    assert_equal account.group_type_mapping, 1 => 'support_agent_group'
    Account.unstub(:group_type_mapping)
  end

  def test_node_feature_list
    Account.current.node_feature_list
    assert_equal response.status, 200
  end

  def test_mark_as
    Account.any_instance.stubs(:save!).returns(true)
    Account.current.mark_as!(:sandbox)
    assert_equal response.status, 200
  ensure
    Account.any_instance.unstub(:save!)
  end

  def test_survey
    Account.stubs(:new_survey_enabled?).returns(true)
    Account.current.survey
    assert_equal response.status, 200
    Account.stubs(:new_survey_enabled?).returns(false)
    Account.current.survey
    assert_equal response.status, 200
  ensure
    Account.unstub(:new_survey_enabled?)
  end

  def test_fields_with_in_operators
    Account.current.fields_with_in_operators
    assert_equal response.status, 200
  end

  def test_installed_apps_hash
    Account.current.installed_apps_hash
    assert_equal response.status, 200
  end

  def test_max_display_id_without_stub
    Account.current.max_display_id
    assert_equal response.status, 200
  end

  def test_account_managers
    Account.current.account_managers
    assert_equal response.status, 200
  end

  def test_reply_emails
    Account.current.reply_emails
    assert_equal response.status, 200
  end

  def test_reply_personalize_emails
    Account.current.reply_personalize_emails('username')
    assert_equal response.status, 200
  end

  def test_support_emails
    Account.current.support_emails
    assert_equal response.status, 200
  end

  def test_parsed_support_emails
    Account.current.parsed_support_emails
    assert_equal response.status, 200
  end

  def test_support_emails_in_downcase
    Account.current.support_emails_in_downcase
    assert_equal response.status, 200
  end

  def test_has_multiple_portals?
    Account.current.has_multiple_portals?
    assert_equal response.status, 200
  end

  def test_enable_ticket_archiving
    Account.current.enable_ticket_archiving
    assert_equal response.status, 200
  end

  def test_set_custom_dashboard_limit
    Account.current.set_custom_dashboard_limit([])
    assert_equal response.status, 200
  end

  def test_verify_account_with_email
    Account.current.verify_account_with_email
    assert_equal response.status, 200
  end

  def test_remove_secondary_companies
    Account.current.remove_secondary_companies
    assert_equal response.status, 200
  end

  def test_ehawk_reputation_score
    Account.any_instance.stubs(:get_others_redis_key).returns('response' => 'resp')
    Account.current.ehawk_reputation_score
    assert_equal response.status, 200
  ensure
    Account.any_instance.unstub(:get_others_redis_key)
  end

  def test_update_ticket_dynamo_shard
    Account.current.update_ticket_dynamo_shard
    assert_equal response.status, 200
  end

  def test_kill_account_activation_email_job
    Account.current.kill_account_activation_email_job
    assert_equal response.status, 200
  end

  def test_signup_method
    Account.current.signup_method
    assert_equal response.status, 200
  end

  def test_active_suspended?
    Account.current.active_suspended?
    assert_equal response.status, 200
  end

  def test_create_freshid_org_and_account
    Account.any_instance.stubs(:freshid_enabled?).returns(true)
    Freshid::Organisation.stubs(:create).returns({})
    User.any_instance.stubs(:sync_profile_from_freshid).returns(true)
    User.any_instance.stubs(:save).returns(true)
    User.any_instance.stubs(:freshid_attributes).returns(1)
    User.any_instance.stubs(:enqueue_activation_email).returns(true)
    Account.current.create_freshid_org_and_account([], [], User.new)
    assert_equal response.status, 200
  ensure
    User.any_instance.unstub(:freshid_attributes)
    User.any_instance.unstub(:enqueue_activation_email)
    User.any_instance.unstub(:sync_profile_from_freshid)
    User.any_instance.unstub(:save)
    Account.any_instance.unstub(:freshid_enabled?)
    Freshid::Organisation.unstub(:create)
  end

  def test_ticket_custom_dropdown_nested_fields
    Account.current.ticket_custom_dropdown_nested_fields
    assert_equal response.status, 200
  end

  def test_esv1
    Account.current.esv1_enabled?
    assert_equal response.status, 200
  end

  def test_permissible_domains
    Account.current.permissible_domains
    assert_equal response.status, 200
  end

  def test_permissible_domains=
    Account.current.permissible_domains=([])
    assert_equal response.status, 200
  end

  def test_public_ticket_token
    Account.current.public_ticket_token
    assert_equal response.status, 200
  end

  def test_attachment_secret
    Account.current.attachment_secret
    assert_equal response.status, 200
  end

  def test_help_widget_secret
    Account.current.help_widget_secret
    assert Account.current.help_widget_secret.is_a?(String)
    assert_equal Account.current.help_widget_secret.length, 32
    assert_equal response.status, 200
  end

  def test_round_robin_capping_enabled?
    Account.current.round_robin_capping_enabled?
    assert_equal response.status, 200
  end

  def test_branding_feature_toggled?
    old_plan_changes = '4208588308347660337495017571860378845317384693225991492345650271073663781650122203171342365763707723357060333567'
    new_plan_changes = '4208588308347660337495017571860378845317384693225991492345650271073663781650122203171342365763131262604756910079'
    previous_changes = { plan_features: [old_plan_changes, new_plan_changes] }
    Account.current.stubs(:previous_changes).returns(previous_changes)
    assert Account.current.branding_feature_toggled?
  ensure
    Account.current.unstub(:previous_changes)
  end

  def test_branding_feature_not_toggled
    old_plan_changes = '4208588308347660337495017571860378845317384693225991492345650271073663781650122203171342365763707723357060333567'
    previous_changes = { plan_features: [old_plan_changes, old_plan_changes] }
    Account.current.stubs(:previous_changes).returns(previous_changes)
    assert_nil Account.current.branding_feature_toggled?
  ensure
    Account.current.unstub(:previous_changes)
  end

  def test_validate_required_ticket_fields?
    Account.current.validate_required_ticket_fields?
    assert_equal response.status, 200
  end

  def test_freshfone_active?
    Account.current.freshfone_active?
    assert_equal response.status, 200
  end

  def test_es_multilang_soln?
    Account.current.es_multilang_soln?
    assert_equal response.status, 200
  end

  def test_active_groups
    Account.current.active_groups
    assert_equal response.status, 200
  end

  def test_has_any_scheduled_ticket_export?
    Account.current.has_any_scheduled_ticket_export?
    assert_equal response.status, 200
  end

  def test_enabled_features_list
    Account.current.enabled_features_list
    assert_equal response.status, 200
  end

  def test_set_time_zone_updation_redis
    Account.current.set_time_zone_updation_redis
    assert_equal response.status, 200
  end

  def test_remove_time_zone_updation_redis
    Account.current.remove_time_zone_updation_redis
    assert_equal response.status, 200
  end

  def test_active_trial
    Account.current.active_trial
    assert_equal response.status, 200
  end

  def test_can_add_agents?
    Account.current.can_add_agents?(1)
    assert_equal response.status, 200
  end

  def test_agent_limit_reached?
    Account.current.support_agent_limit_reached?(1)
    assert_equal response.status, 200
  end

  def test_max_display_id
    Account.any_instance.stubs(:features?).returns(true)
    Account.current.max_display_id
    assert_equal response.status, 200
  ensure
    Account.any_instance.unstub(:features?)
  end

  def test_active?
    Account.current.active?
    assert_equal response.status, 200
  end

  def test_suspended?
    Account.current.suspended?
    assert_equal response.status, 200
  end

  def test_master_queries?
    Account.current.master_queries?
    assert_equal response.status, 200
  end

  def test_premium_gamification_account?
    Account.current.premium_gamification_account?
    assert_equal response.status, 200
    Account.current.default_friendly_email
    assert_equal response.status, 200
    Account.current.default_friendly_email_personalize('user_name')
    assert_equal response.status, 200
    Account.current.default_email
    assert_equal response.status, 200
  end

  def test_host
    Account.current.host
    Account.current.full_url
    Account.current.url_protocol
  end

  def test_remove_feature
    Account.current.has_multiple_products?
    Account.current.kbase_email
    Account.current.has_credit_card?
  end

  def test_date_type
    Account.current.date_type('%b %-d %Y')
    Account.current.default_form
  end

  def test_portal_languages
    Account.current.portal_languages
    Account.current.onboarding_pending?
    assert_equal response.status, 200
    Account.current.advanced_twitter?
    assert_equal response.status, 200
    Account.current.add_twitter_handle?
    assert_equal response.status, 200
    Account.current.add_custom_twitter_stream?
    assert_equal response.status, 200
    Account.current.twitter_feature_present?
  end

  def test_ehawk_spam?
    Account.current.ehawk_spam?
    Account.current.dashboard_shard_name
    Account.current.schedule_account_activation_email(1)
  end

  def test_versionize_timestamp
    Account.current.versionize_timestamp
    assert_equal response.status, 200
    Account.current.email_service_provider
    assert_equal response.status, 200
    Account.current.full_signup?
    assert_equal response.status, 200
    Account.current.allow_incoming_emails?
    assert_equal response.status, 200
    Account.current.email_subscription_state
    Account.current.bots_hash
  end

  def test_create_freshid_account_with_user_for_org
    Freshid::Organisation.stubs(:create).returns(true)
    Freshid::Organisation.stubs(:create_for_account).returns(true)
    Freshid::Organisation.any_instance.stubs(:map_to_account).returns(true)
    Account.current.create_freshid_org_without_account_and_user
    assert_equal response.status, 200
    Account.current.map_freshid_org_to_account(1)
    assert_equal response.status, 200
    Account.current.freshid_attributes
  ensure
    Freshid::Organisation.any_instance.unstub(:map_to_account)
    Freshid::Organisation.unstub(:create)
    Freshid::Organisation.unstub(:create_for_account)
    Freshid::Organisation.unstub(:new)
  end

  def test_sync_user_info_from_freshid
    Account.any_instance.stubs(:redis_key_exists?).returns(true)
    Account.current.initiate_freshid_migration
    assert_equal response.status, 200
    Account.current.freshid_migration_complete
    assert_equal response.status, 200
    Account.current.freshid_migration_in_progress?
    assert_equal response.status, 200
  ensure
    Account.any_instance.unstub(:redis_key_exists?)
  end

  def test_account_cancellation_request_job_key
    Account.current.kill_account_cancellation_request_job
    assert_equal response.status, 200
    Account.current.delete_account_cancellation_request_job_key
    assert_equal response.status, 200
    Account.current.canned_responses_inline_images
    Account.current.contact_custom_field_types
    assert_equal response.status, 200
    Account.current.company_custom_field_types
    assert_equal response.status, 200
    Account.current.sandbox_domain
  end

  def test_bot_email_response
    Account.current.bot_email_response
    assert_equal response.status, 200
    Account.current.falcon_and_encrypted_fields_enabled?
    assert_equal response.status, 200
  end

  def test_hipaa_and_encrypted_fields_enabled
    Account.current.hipaa_and_encrypted_fields_enabled?
    assert_equal response.status, 200
    Account.current.remove_encrypted_fields
    assert_equal response.status, 200
    Account.current.hipaa_encryption_key
    assert_equal response.status, 200
    Account.current.beacon_report
    Account.current.force_2020_plan?
    assert_equal response.status, 200
    Account.current.new_2020_pricing_enabled?
    assert_equal response.status, 200
  end

  def test_reseller_paid_account?
    Account.current.reseller_paid_account?
    assert_equal response.status, 200
  end

  def test_freshsales_account_info_with_application
    CRM::FreshsalesUtility.any_instance.stubs(:request_account_info).returns(stub_freshsales_response)
    Account.any_instance.stubs(:account_activated_within_last_week?).returns(true)
    Account.any_instance.stubs(:installed_applications).returns(stub_installed_application)
    Integrations::InstalledApplication.any_instance.stubs(:with_name).returns([stub_installed_application])
    CRM::FreshsalesUtility.any_instance.stubs(:get_entity_id).returns(1)
    Account.current.account_additional_settings.additional_settings[:freshdesk_freshsales_bundle] = true
    response = Account.current.fetch_fd_fs_banner_details
    assert_equal response[:state], 'trial'
    assert_equal response[:url], 'https://test-001.freshsales.io/subscription'
  ensure
    CRM::FreshsalesUtility.any_instance.unstub(:request_account_info)
    Account.any_instance.unstub(:created_at)
    Account.any_instance.unstub(:installed_applications)
    Integrations::InstalledApplication.any_instance.unstub(:with_name)
    CRM::FreshsalesUtility.any_instance.unstub(:get_entity_id)
    Account.current.account_additional_settings.additional_settings[:freshdesk_freshsales_bundle] = nil
  end

  def test_freshsales_account_info_without_application
    CRM::FreshsalesUtility.any_instance.stubs(:request_account_info).returns(stub_freshsales_response)
    Account.any_instance.stubs(:account_activated_within_last_week?).returns(true)
    CRM::FreshsalesUtility.any_instance.stubs(:get_entity_id).returns(1)
    Account.current.account_additional_settings.additional_settings[:freshdesk_freshsales_bundle] = true
    response = Account.current.fetch_fd_fs_banner_details
    assert_equal response[:state], 'new'
  ensure
    CRM::FreshsalesUtility.any_instance.unstub(:request_account_info)
    Account.any_instance.unstub(:created_at)
    CRM::FreshsalesUtility.any_instance.unstub(:get_entity_id)
    Account.current.account_additional_settings.additional_settings[:freshdesk_freshsales_bundle] = nil
  end

  def test_freshsales_account_info_without_application_with_freshsales
    CRM::FreshsalesUtility.any_instance.stubs(:request_account_info).returns(stub_freshsales_response)
    Account.any_instance.stubs(:account_activated_within_last_week?).returns(true)
    Account.any_instance.stubs(:freshsales_account_from_freshid).returns('test.freshsales.io')
    CRM::FreshsalesUtility.any_instance.stubs(:get_entity_id).returns(1)
    Account.current.account_additional_settings.additional_settings[:freshdesk_freshsales_bundle] = true
    response = Account.current.fetch_fd_fs_banner_details
    assert_equal response[:state], 'integrate'
  ensure
    CRM::FreshsalesUtility.any_instance.unstub(:request_account_info)
    Account.any_instance.unstub(:created_at)
    Account.any_instance.unstub(:freshsales_account_from_freshid)
    CRM::FreshsalesUtility.any_instance.unstub(:get_entity_id)
    Account.current.account_additional_settings.additional_settings[:freshdesk_freshsales_bundle] = nil
  end

  def test_freshsales_account_info_old_account
    CRM::FreshsalesUtility.any_instance.stubs(:request_account_info).returns(stub_freshsales_response)
    Account.any_instance.stubs(:account_activated_within_last_week?).returns(false)
    CRM::FreshsalesUtility.any_instance.stubs(:get_entity_id).returns(1)
    response = Account.current.fetch_fd_fs_banner_details
    assert_nil response
  ensure
    CRM::FreshsalesUtility.any_instance.unstub(:request_account_info)
    Account.any_instance.unstub(:created_at)
    CRM::FreshsalesUtility.any_instance.unstub(:get_entity_id)
  end

  def test_rolling_back_of_advanced_ticket_scope_feature
    Sidekiq::Testing.inline! do
      Account.current.add_feature(:advanced_ticket_scopes)
      dummy_user = Account.current.technicians.first
      group_id = Account.current.groups.first.id
      dummy_user.agent.agent_groups.new.tap { |ag| ag.group_id = group_id; ag.write_access = false; ag.save! }
      assert_equal 1, Account.current.agent_groups.where('user_id = ? and write_access = ?', dummy_user.id, 0).count
      Account.current.revoke_feature(:advanced_ticket_scopes)
      @account = create_test_account
      @account.make_current
      assert Account.current.agent_groups.where('user_id = ? and write_access = ?', dummy_user.id, 0).count.zero?
    end
  end

  def stub_freshsales_response
    [200, { 'accounts': [{ 'id': 1, 'subscription_state': 'trial', 'full_domain': 'test-001.freshsales.io' }] }]
  end

  def stub_installed_application
    installed_app = Integrations::InstalledApplication.new
    installed_app.set_configs(domain: 'test.freshsales.io', auth_token: 'abcd1234')
    installed_app
  end

  def test_should_not_show_omnichannel_banner_without_lp
    Account.current.rollback(:explore_omnichannel_feature)
    refute Account.current.show_omnichannel_banner?
  end

  def test_should_not_show_omnichannel_banner_for_non_freshid_org_v2_accounts
    Account.current.rollback(:freshid_org_v2)
    refute Account.current.show_omnichannel_banner?
  end

  def test_should_not_show_omnichannel_banner_with_lp_and_for_omni_bundle_account
    Account.current.launch(:explore_omnichannel_feature)
    Account.current.launch(:freshid_org_v2)
    Account.current.launch(:omni_bundle_2020)
    AccountAdditionalSettings.any_instance.stubs(:additional_settings).returns(bundle_id: 1)
    refute Account.current.show_omnichannel_banner?
  ensure
    Account.current.rollback(:explore_omnichannel_feature)
    Account.current.rollback(:freshid_org_v2)
    Account.current.rollback(:omni_bundle_2020)
    AccountAdditionalSettings.any_instance.unstub(:additional_settings)
  end

  def test_show_omnichannel_banner_with_lp_and_not_omni_bundle_account
    Account.current.launch(:explore_omnichannel_feature)
    Account.current.launch(:freshid_org_v2)
    Account.any_instance.stubs(:verified?).returns(true)
    AccountAdditionalSettings.any_instance.stubs(:additional_settings).returns(bundle_id: nil)
    assert Account.current.show_omnichannel_banner?
  ensure
    Account.current.rollback(:explore_omnichannel_feature)
    Account.current.rollback(:freshid_org_v2)
    Account.any_instance.unstub(:verified?)
    AccountAdditionalSettings.any_instance.unstub(:additional_settings)
  end

  def test_should_not_show_omnichannel_banner_for_accounts_with_pending_cancellation_request
    Account.current.launch(:explore_omnichannel_feature)
    Account.current.launch(:freshid_org_v2)
    AccountAdditionalSettings.any_instance.stubs(:additional_settings).returns({})
    Account.any_instance.stubs(:account_cancellation_requested?).returns(true)
    SubscriptionPlan.any_instance.stubs(:omni_plan?).returns(false)
    Subscription.any_instance.stubs(:state).returns('active')
    refute Account.current.show_omnichannel_banner?
  ensure
    Account.current.rollback(:explore_omnichannel_feature)
    Account.current.rollback(:freshid_org_v2)
    AccountAdditionalSettings.any_instance.unstub(:additional_settings)
    Account.any_instance.unstub(:account_cancellation_requested?)
    SubscriptionPlan.any_instance.unstub(:omni_plan?)
    Subscription.any_instance.unstub(:state)
  end

  def test_should_not_show_omnichannel_banner_for_unverified_accounts
    User.any_instance.stubs(:privilege?).returns(true)
    Account.current.launch(:explore_omnichannel_feature)
    Account.current.launch(:freshid_org_v2)
    AccountAdditionalSettings.any_instance.stubs(:additional_settings).returns({})
    Account.any_instance.stubs(:account_cancellation_requested?).returns(false)
    SubscriptionPlan.any_instance.stubs(:omni_plan?).returns(false)
    Subscription.any_instance.stubs(:state).returns('active')
    Account.any_instance.stubs(:verified?).returns(false)
    refute Account.current.show_omnichannel_banner?
  ensure
    User.any_instance.unstub(:privilege?)
    Account.current.rollback(:explore_omnichannel_feature)
    Account.current.rollback(:freshid_org_v2)
    AccountAdditionalSettings.any_instance.unstub(:additional_settings)
    Account.any_instance.unstub(:account_cancellation_requested?)
    SubscriptionPlan.any_instance.unstub(:omni_plan?)
    Subscription.any_instance.unstub(:state)
    Account.any_instance.unstub(:verified?)
  end
end
