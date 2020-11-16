require_relative '../../test_helper'
require Rails.root.join('test', 'api', 'helpers', 'admin', 'security_test_helper.rb')

class Admin::ApiSecurityControllerTest < ActionController::TestCase
  include Admin::SecurityTestHelper
  include UsersHelper

  def test_show_whitelisted_ips_not_enabled
    Account.any_instance.stubs(:whitelisted_ips_enabled?).returns(false)
    get :show, controller_params
    assert_response 200
    refute_includes JSON.parse(response.body), 'whitelisted_ip'
  ensure
    Account.any_instance.unstub(:whitelisted_ips_enabled?)
  end

  def test_show_whitelisted_ip_enabled
    Account.any_instance.stubs(:whitelisted_ips_enabled?).returns(true)
    Account.current.stubs(:whitelisted_ip).returns(nil)
    get :show, controller_params
    assert_response 200
    assert_equal whitelisted_ip_not_configured, JSON.parse(response.body)['whitelisted_ip']
  ensure
    Account.any_instance.unstub(:whitelisted_ips_enabled?)
  end

  def test_show_help_widget_not_enabled
    Account.any_instance.stubs(:help_widget_enabled?).returns(false)
    get :show, controller_params
    assert_response 200
    refute_includes JSON.parse(response.body), 'help_widget'
  ensure
    Account.any_instance.unstub(:help_widget_enabled?)
  end

  def test_show_custom_password_policy_not_enabled
    Account.any_instance.stubs(:custom_password_policy_enabled?).returns(false)
    get :show, controller_params
    assert_response 200
    assert_nil JSON.parse(response.body)['agent_password_policy']
    assert_nil JSON.parse(response.body)['contact_password_policy']
  ensure
    Account.any_instance.unstub(:custom_password_policy_enabled?)
  end

  def test_show_password_policy_with_freshid_integration_enabled
    Account.any_instance.stubs(:freshid_integration_enabled?).returns(true)
    get :show, controller_params
    assert_response 200
    refute_includes JSON.parse(response.body), 'agent_password_policy'
    assert_equal password_policy.stringify_keys, JSON.parse(response.body)['contact_password_policy']
  ensure
    Account.any_instance.unstub(:freshid_integration_enabled?)
  end

  def test_show_account_current_ip
    get :show, controller_params
    assert_response 200
    assert_equal request.remote_ip, response.api_meta[:current_ip]
  end

  def test_show_account_current_ip_when_whitelisted_ip_disabled
    Account.any_instance.stubs(:whitelisted_ips_enabled?).returns(false)
    get :show, controller_params
    assert_response 200
    refute_includes response.api_meta, :current_ip
  ensure
    Account.any_instance.unstub(:whitelisted_ips_enabled?)
  end

  def test_show_account_freshid_migration_not_in_process
    Account.current.stubs(:freshid_migration_in_progress?).returns(false)
    get :show, controller_params(version: 'private')
    assert_response 200
    assert_equal false, response.api_meta[:freshid_migration_in_progress]
  ensure
    Account.current.unstub(:freshid_migration_in_progress)
  end

  def test_show_account_freshid_migration_in_process
    Account.current.stubs(:freshid_migration_in_progress?).returns(true)
    get :show, controller_params(version: 'private')
    assert_response 200
    assert response.api_meta[:freshid_migration_in_progress]
  ensure
    Account.current.unstub(:freshid_migration_in_progress)
  end

  def test_account_freshid_sso_enabled
    Account.current.stubs(:freshid_sso_enabled?).returns(true)
    get :show, controller_params(version: 'private')
    assert_response 200
    assert_equal true, response.api_meta[:freshid_sso_enabled]
  ensure
    Account.current.unstub(:freshid_sso_enabled)
  end

  def test_show_settings_secure_fields_toggle_disabled
    Account.current.stubs(:secure_fields_toggle_enabled?).returns(false)
    get :show, controller_params(version: 'private')
    assert_response 200
    refute_includes JSON.parse(response.body), 'secure_fields'
  ensure
    Account.current.unstub(:secure_fields_toggle_enabled?)
  end

  def test_show_settings_secure_fields_toggle_enabled_and_feature_disabled
    Account.current.stubs(:secure_fields_toggle_enabled?).returns(true)
    Account.current.stubs(:secure_fields_enabled?).returns(false)
    get :show, controller_params(version: 'private')
    assert_response 200
    assert_equal false, JSON.parse(response.body)['secure_fields']
  ensure
    Account.current.unstub(:secure_fields_toggle_enabled?)
    Account.current.unstub(:secure_fields_enabled?)
  end

  def test_show_settings_secure_fields_toggle_enabled_and_feature_enabled
    Account.current.stubs(:secure_fields_toggle_enabled?).returns(true)
    Account.current.stubs(:secure_fields_enabled?).returns(true)
    get :show, controller_params(version: 'private')
    assert_response 200
    assert_equal true, JSON.parse(response.body)['secure_fields']
  ensure
    Account.current.unstub(:secure_fields_toggle_enabled?)
    Account.current.unstub(:secure_fields_enabled?)
  end

  def test_show_security_index_public_api
    stub_account
    CustomRequestStore.stubs(:read).with(:private_api_request).returns(false)
    get :show, controller_params(version: 'v2')
    assert_response 200
    match_json(security_index_api_response_pattern(public_api: true))
  ensure
    unstub_account
    CustomRequestStore.unstub(:read)
  end

  def test_security_index_public_api_sso
    stub_account
    CustomRequestStore.stubs(:read).with(:private_api_request).returns(false)
    Account.any_instance.stubs(:sso_enabled).returns(true)
    Account.any_instance.stubs(:freshdesk_sso_enabled?).returns(true)
    Account.any_instance.stubs(:sso_options).returns(HashWithIndifferentAccess.new(sso_type: 'simple', login_url: 'abc.com'))
    get :show, controller_params(version: 'v2')
    assert_response 200
    match_json(security_index_api_response_pattern(public_api: true))
  ensure
    unstub_account
    CustomRequestStore.unstub(:read)
    Account.any_instance.unstub(:sso_enabled)
    Account.any_instance.unstub(:freshdesk_sso_enabled?)
    Account.any_instance.unstub(:sso_options)
  end

  def test_show_security_index_private_api
    stub_account
    get :show, controller_params(version: 'private')
    assert_response 200
    match_json(security_index_api_response_pattern)
  ensure
    unstub_account
  end

  def test_show_security_index_private_api_in_non_freshid_v2_accounts_saml
    Account.any_instance.stubs(:freshdesk_sso_configurable?).returns(true)
    Account.any_instance.stubs(:sso_enabled).returns(true)
    sso_option = HashWithIndifferentAccess.new(sso_type: 'saml', saml_login_url: 'saml_url', saml_logout_url: 'logout_url')
    Account.any_instance.stubs(:sso_options).returns(sso_option)
    stub_account
    get :show, controller_params(version: 'private')
    assert_response 200
    response_body = JSON.parse(response.body)
    assert_equal sso_option[:sso_type], response_body['sso']['type']
    assert_equal sso_option[:saml_login_url], response_body['sso']['saml']['login_url']
    assert_equal sso_option[:saml_logout_url], response_body['sso']['saml']['logout_url']
  ensure
    unstub_account
    Account.any_instance.unstub(:freshdesk_sso_configurable?)
    Account.any_instance.unstub(:sso_options)
    Account.any_instance.unstub(:sso_enabled)
  end

  def test_show_security_index_private_api_in_non_freshid_v2_accounts_simple_sso
    Account.any_instance.stubs(:freshdesk_sso_configurable?).returns(true)
    Account.any_instance.stubs(:sso_enabled).returns(true)
    sso_option = HashWithIndifferentAccess.new(sso_type: 'simple', login_url: 'simple_url', logout_url: 'logout_url')
    Account.any_instance.stubs(:sso_options).returns(sso_option)
    stub_account
    get :show, controller_params(version: 'private')
    assert_response 200
    response_body = JSON.parse(response.body)
    assert_equal sso_option[:sso_type], response_body['sso']['type']
    assert_equal sso_option[:login_url], response_body['sso']['simple']['login_url']
    assert_equal sso_option[:logout_url], response_body['sso']['simple']['logout_url']
  ensure
    unstub_account
    Account.any_instance.unstub(:freshdesk_sso_configurable?)
    Account.any_instance.unstub(:sso_options)
    Account.any_instance.unstub(:sso_enabled)
  end

  def test_show_security_index_private_api_in_oauth2_accounts
    Account.any_instance.stubs(:freshdesk_sso_configurable?).returns(true)
    Account.any_instance.stubs(:sso_enabled).returns(true)
    sso_option = HashWithIndifferentAccess.new(sso_type: 'oauth2', customer_oauth2: true)
    Account.any_instance.stubs(:sso_options).returns(sso_option)
    stub_account
    get :show, controller_params(version: 'private')
    assert_response 200
    response_body = JSON.parse(response.body)
    assert_equal sso_option[:sso_type], response_body['sso']['type']
  ensure
    unstub_account
    Account.any_instance.unstub(:freshdesk_sso_configurable?)
    Account.any_instance.unstub(:sso_options)
    Account.any_instance.unstub(:sso_enabled)
  end

  def test_show_security_index_private_api_in_freshid_saml_accounts
    Account.any_instance.stubs(:freshdesk_sso_configurable?).returns(true)
    Account.any_instance.stubs(:sso_enabled).returns(true)
    sso_option = HashWithIndifferentAccess.new(sso_type: 'freshid_saml', agent_freshid_saml: true)
    Account.any_instance.stubs(:sso_options).returns(sso_option)
    stub_account
    get :show, controller_params(version: 'private')
    assert_response 200
    response_body = JSON.parse(response.body)
    assert_equal sso_option[:sso_type], response_body['sso']['type']
  ensure
    unstub_account
    Account.any_instance.unstub(:freshdesk_sso_configurable?)
    Account.any_instance.unstub(:sso_options)
    Account.any_instance.unstub(:sso_enabled)
  end

  def test_show_security_index_private_api_in_freshid_v2_sso
    Account.any_instance.stubs(:freshdesk_sso_configurable?).returns(false)
    stub_account
    get :show, controller_params(version: 'private')
    assert_response 200
    response_body = JSON.parse(response.body)
    refute response_body.key?(:sso)
  ensure
    unstub_account
    Account.any_instance.unstub(:freshdesk_sso_configurable?)
  end

  def test_security_index_redaction_not_configured
    Account.any_instance.stubs(:redaction_enabled?).returns(true)
    Account.any_instance.stubs(:redaction).returns(nil)
    stub_account
    expected_response = { 'credit_card_number' => false }
    get :show, controller_params(version: 'private')
    assert_response 200
    response_body = JSON.parse(response.body)
    assert_equal expected_response, response_body['redaction']
  ensure
    unstub_account
    Account.any_instance.unstub(:redaction_enabled?)
    Account.any_instance.unstub(:redaction)
  end

  def test_security_index_redaction_with_redaction_configured
    Account.any_instance.stubs(:redaction_enabled?).returns(true)
    redaction_data = { 'credit_card_number' => true }.with_indifferent_access
    Account.any_instance.stubs(:redaction).returns(redaction_data)
    stub_account
    get :show, controller_params(version: 'private')
    assert_response 200
    response_body = JSON.parse(response.body)
    assert_equal redaction_data, response_body['redaction']
  ensure
    unstub_account
    Account.any_instance.unstub(:redaction_enabled?)
    Account.any_instance.unstub(:redaction)
  end

  def test_security_index_redaction_with_redaction_disabled
    Account.any_instance.stubs(:redaction_enabled?).returns(false)
    stub_account
    get :show, controller_params(version: 'private')
    assert_response 200
    response_body = JSON.parse(response.body)
    refute response_body.key?(:redaction)
  ensure
    unstub_account
    Account.any_instance.unstub(:redaction_enabled?)
  end

  def test_update_notification_emails
    AccountConfiguration.any_instance.stubs(:update_billing).returns(true)
    agent = add_test_agent(Account.current)
    email = agent.email
    @account.reload
    request_params = {
      notification_emails: [email]
    }
    put :update, construct_params(api_security: request_params)
    assert_response 200
    assert_equal [email], @account.account_configuration.contact_info[:notification_emails]
  ensure
    AccountConfiguration.any_instance.unstub(:update_billing)
    agent.destroy
  end

  def test_update_duplicate_notification_emails
    AccountConfiguration.any_instance.stubs(:update_billing).returns(true)
    agent = add_test_agent(Account.current)
    email = agent.email
    @account.reload
    email_list = [email, email, email]
    request_params = {
      notification_emails: email_list
    }
    put :update, construct_params(api_security: request_params)
    assert_response 400
    match_json([bad_request_error_pattern(:notification_emails, :duplicate_not_allowed, name: 'notification_emails', list: email_list.uniq.join(', '))])
  ensure
    AccountConfiguration.any_instance.unstub(:update_billing)
    agent.destroy
  end

  def test_update_notification_emails_with_non_manager_email
    request_params = {
      notification_emails: ['non.manager.email@gmail.com']
    }
    put :update, construct_params(api_security: request_params)
    assert_response 400
    match_json([bad_request_error_pattern(:notification_emails, :not_included, list: 'account_managers emails', attribute: :notification_emails)])
  end

  def test_update_contact_password_policy
    Account.any_instance.stubs(:custom_password_policy_enabled?).returns(true)
    request_params = {
      contact_password_policy: {
        cannot_be_same_as_past_passwords: 2,
        cannot_contain_user_name: true
      }
    }
    put :update, construct_params(api_security: request_params)
    assert_response 200
    assert Account.current.contact_password_policy.advanced_policy?
    assert_empty request_params[:contact_password_policy].except(:type).keys - @account.contact_password_policy.policies
    assert_equal Account.current.contact_password_policy.configs['cannot_be_same_as_past_passwords'], request_params[:contact_password_policy][:cannot_be_same_as_past_passwords].to_s
  ensure
    Account.any_instance.unstub(:custom_password_policy_enabled?)
  end

  def test_update_contact_password_policy_with_sso_enabled
    Account.any_instance.stubs(:custom_password_policy_enabled?).returns(true)
    Account.any_instance.stubs(:sso_enabled?).returns(true)
    request_params = {
      contact_password_policy: {
        cannot_be_same_as_past_passwords: 2,
        cannot_contain_user_name: true
      }
    }
    put :update, construct_params(api_security: request_params)
    assert_response 400
    match_json([bad_request_error_pattern(:contact_password_policy, :action_restricted, action: 'password policies update', reason: 'when sso is enabled')])
  ensure
    Account.any_instance.unstub(:custom_password_policy_enabled?)
    Account.any_instance.unstub(:sso_enabled?)
  end

  def test_update_contact_password_policy_without_feature
    Account.any_instance.stubs(:custom_password_policy_enabled?).returns(false)
    request_params = {
      contact_password_policy: {
        cannot_be_same_as_past_passwords: 3,
        cannot_contain_user_name: true,
        have_special_character: false
      }
    }
    put :update, construct_params(api_security: request_params)
    assert_response 400
    match_json([bad_request_error_pattern(:contact_password_policy, :require_feature_for_attribute, feature: 'custom_password_policy', attribute: 'contact_password_policy')])
  ensure
    Account.any_instance.unstub(:custom_password_policy_enabled?)
  end

  def test_update_agent_default_password_policy
    Account.any_instance.stubs(:custom_password_policy_enabled?).returns(true)
    Account.any_instance.stubs(:freshid_enabled?).returns(false)
    Account.any_instance.stubs(:freshid_org_v2_enabled?).returns(false)
    request_params = {
      agent_password_policy: {
        minimum_characters: 8,
        cannot_contain_user_name: true,
        password_expiry: 36_500,
        cannot_be_same_as_past_passwords: nil,
        atleast_an_alphabet_and_number: nil,
        have_mixed_case: nil,
        have_special_character: nil
      }
    }
    put :update, construct_params(api_security: request_params)
    assert_response 200
    assert @account.agent_password_policy.default_policy?
  ensure
    Account.any_instance.unstub(:custom_password_policy_enabled?)
    Account.any_instance.unstub(:freshid_enabled?)
    Account.any_instance.unstub(:freshid_org_v2_enabled?)
  end

  def test_update_agent_password_policy
    Account.any_instance.stubs(:custom_password_policy_enabled?).returns(true)
    Account.any_instance.stubs(:freshid_enabled?).returns(false)
    Account.any_instance.stubs(:freshid_org_v2_enabled?).returns(false)
    password_policy = Account.current.build_agent_password_policy(user_type: 2)
    password_policy.save
    request_params = {
      agent_password_policy: {
        minimum_characters: 78,
        cannot_be_same_as_past_passwords: 4
      }
    }
    put :update, construct_params(api_security: request_params)
    assert_response 200
    password_policy.reload
    assert password_policy.advanced_policy?
    assert_equal request_params[:agent_password_policy][:minimum_characters].to_s, password_policy.configs['minimum_characters']
    assert_equal request_params[:agent_password_policy][:cannot_be_same_as_past_passwords].to_s, password_policy.configs['cannot_be_same_as_past_passwords']
  ensure
    Account.any_instance.unstub(:custom_password_policy_enabled?)
    Account.any_instance.unstub(:freshid_integration_enabled?)
    Account.any_instance.unstub(:freshid_org_v2_enabled?)
    password_policy.destroy
  end

  def test_update_contact_password_policy_to_advanced
    Account.any_instance.stubs(:custom_password_policy_enabled?).returns(true)
    request_params = {
      contact_password_policy: {
        have_mixed_case: true
      }
    }
    put :update, construct_params(api_security: request_params)
    assert_response 200
    assert Account.current.contact_password_policy.advanced_policy?
    assert Account.current.contact_password_policy.is_policy?(:have_mixed_case)
  ensure
    Account.any_instance.unstub(:custom_password_policy_enabled?)
  end

  def test_show_secure_attachments
    Account.any_instance.stubs(:security_new_settings_enabled?).returns(true)
    Account.any_instance.stubs(:secure_attachments_enabled?).returns(true)
    Account.current.add_feature(:basic_settings_feature)
    get :show, controller_params
    assert_response 200
    assert_equal JSON.parse(response.body)['secure_attachments_enabled'], true
  ensure
    Account.any_instance.unstub(:security_new_settings_enabled?)
    Account.any_instance.unstub(:secure_attachments_enabled?)
  end

  def test_enable_secure_attachments
    Account.current.add_feature(:basic_settings_feature)
    Account.any_instance.stubs(:security_new_settings_enabled?).returns(true)
    request_params = {
      secure_attachments_enabled: true
    }
    put :update, construct_params(api_security: request_params)
    assert_response 200
    assert_equal Account.current.secure_attachments_enabled?, true
  ensure
    Account.current.disable_setting(:secure_attachments)
    Account.any_instance.unstub(:security_new_settings_enabled?)
  end

  def test_disable_secure_attachments
    Account.any_instance.stubs(:security_new_settings_enabled?).returns(true)
    Account.current.add_feature(:basic_settings_feature)
    Account.current.enable_setting(:secure_attachments)
    request_params = {
      secure_attachments_enabled: false
    }
    put :update, construct_params(api_security: request_params)
    assert_response 200
    assert_equal Account.current.secure_attachments_enabled?, false
  ensure
    Account.any_instance.unstub(:security_new_settings_enabled?)
  end

  def test_update_secure_attachments_without_launch_party
    Account.any_instance.stubs(:security_new_settings_enabled?).returns(false)
    request_params = {
      secure_attachments_enabled: true
    }
    put :update, construct_params(api_security: request_params)
    assert_response 400
    match_json([bad_request_error_pattern(:secure_attachments_enabled, :invalid_field, attribute: 'input')])
  ensure
    Account.any_instance.unstub(:security_new_settings_enabled?)
  end

  def test_update_secure_attachments_without_dependent_feature
    Account.any_instance.stubs(:security_new_settings_enabled?).returns(true)
    Account.current.revoke_feature(:basic_settings_feature)
    request_params = {
      secure_attachments_enabled: true
    }
    put :update, construct_params(api_security: request_params)
    assert_response 403
    match_json(request_error_pattern(:require_feature, feature: 'secure_attachments'))
  ensure
    Account.any_instance.unstub(:security_new_settings_enabled?)
    Account.current.add_feature(:basic_settings_feature)
  end

  def test_show_secure_attachments_without_dependent_feature
    Account.any_instance.stubs(:security_new_settings_enabled?).returns(true)
    Account.current.revoke_feature(:basic_settings_feature)
    Account.any_instance.stubs(:secure_attachments_enabled?).returns(true)
    get :show, controller_params
    assert_response 200
    assert_nil JSON.parse(response.body)['secure_attachments_enabled']
  ensure
    Account.any_instance.unstub(:security_new_settings_enabled?)
    Account.current.add_feature(:basic_settings_feature)
  end

  def test_show_secure_attachments_without_launchparty
    Account.any_instance.stubs(:security_new_settings_enabled?).returns(false)
    Account.any_instance.stubs(:secure_attachments_enabled?).returns(true)
    get :show, controller_params
    assert_response 200
    assert_nil JSON.parse(response.body)['secure_attachments_enabled']
  ensure
    Account.any_instance.unstub(:security_new_settings_enabled?)
    Account.any_instance.unstub(:secure_attachments_enabled?)
  end

  def test_update_agent_password_policy_without_custom_password_policy_features
    Account.any_instance.stubs(:custom_password_policy_enabled?).returns(false)
    request_params = {
      agent_password_policy: {
        minimum_characters: 45,
        cannot_be_same_as_past_passwords: 3,
        cannot_contain_user_name: true,
        have_special_character: false,
        have_mixed_case: true
      }
    }
    put :update, construct_params(api_security: request_params)
    assert_response 400
    match_json([bad_request_error_pattern(:agent_password_policy, :require_feature_for_attribute, feature: 'custom_password_policy', attribute: 'agent_password_policy')])
  ensure
    Account.any_instance.unstub(:custom_password_policy_enabled?)
  end

  def test_update_agent_password_policy_with_freshid_features
    Account.any_instance.stubs(:custom_password_policy_enabled?).returns(true)
    Account.any_instance.stubs(:freshid_enabled?).returns(true)
    request_params = {
      agent_password_policy: {
        minimum_characters: 45,
        cannot_be_same_as_past_passwords: 3,
        cannot_contain_user_name: true,
        have_special_character: false,
        have_mixed_case: true
      }
    }
    put :update, construct_params(api_security: request_params)
    assert_response 400
    match_json([bad_request_error_pattern(:agent_password_policy, :action_restricted, action: 'update agent_password_policy', reason: 'freshid enabled')])
  ensure
    Account.any_instance.unstub(:custom_password_policy_enabled?)
    Account.any_instance.unstub(:freshid_enabled?)
  end

  def test_update_agent_password_policy_with_freshid_org_v2_features
    Account.any_instance.stubs(:custom_password_policy_enabled?).returns(true)
    Account.any_instance.stubs(:freshid_org_v2_enabled?).returns(true)
    request_params = {
      agent_password_policy: {
        minimum_characters: 45,
        cannot_be_same_as_past_passwords: 3,
        cannot_contain_user_name: true,
        have_special_character: false,
        have_mixed_case: true
      }
    }
    put :update, construct_params(api_security: request_params)
    assert_response 400
    match_json([bad_request_error_pattern(:agent_password_policy, :action_restricted, action: 'update agent_password_policy', reason: 'freshid_org_v2 enabled')])
  ensure
    Account.any_instance.unstub(:custom_password_policy_enabled?)
    Account.any_instance.unstub(:freshid_org_v2_enabled?)
  end

  def test_update_whitelisted_ip
    Account.any_instance.stubs(:whitelisted_ips_enabled?).returns(true)
    @request.env['CLIENT_IP'] = '111.11.00.110'
    request_params = {
      whitelisted_ip: {
        enabled: true,
        applies_only_to_agents: true,
        ip_ranges: [{
          start_ip: '111.11.00.11',
          end_ip: '111.11.00.111'
        }]
      }
    }
    put :update, construct_params(api_security: request_params)
    assert_response 200
    assert @account.whitelisted_ip.enabled
    assert @account.whitelisted_ip.applies_only_to_agents
    assert_equal request_params[:whitelisted_ip][:ip_ranges].first.with_indifferent_access, @account.whitelisted_ip.ip_ranges.first
  ensure
    Account.any_instance.unstub(:whitelisted_ips_enabled?)
    Account.current.whitelisted_ip.try(:destroy)
  end

  def test_update_whitelisted_ip_v6
    Account.any_instance.stubs(:whitelisted_ips_enabled?).returns(true)
    @request.env['CLIENT_IP'] = '2001:db8:001f:ffff:ffff:ffff:ffff:0001'
    request_params = {
      whitelisted_ip: {
        enabled: true,
        applies_only_to_agents: true,
        ip_ranges: [{
          start_ip: '2001:db8:001f:ffff:ffff:ffff:ffff:0000',
          end_ip: '2001:db8:001f:ffff:ffff:ffff:ffff:ffff'
        }]
      }
    }
    put :update, construct_params(api_security: request_params)
    assert_response 200
    assert @account.whitelisted_ip.enabled
    assert @account.whitelisted_ip.applies_only_to_agents
    assert_equal request_params[:whitelisted_ip][:ip_ranges].first.with_indifferent_access, @account.whitelisted_ip.ip_ranges.first
  ensure
    Account.any_instance.unstub(:whitelisted_ips_enabled?)
    Account.current.whitelisted_ip.try(:destroy)
  end

  def test_update_whitelisted_ip_limit_exceeded
    Account.any_instance.stubs(:whitelisted_ips_enabled?).returns(true)
    @request.env['CLIENT_IP'] = '111.11.00.110'
    ip_ranges = []
    501.times do
      ip_ranges << { start_ip: '111.11.00.11', end_ip: '111.11.00.111' }
    end
    request_params = {
      whitelisted_ip: {
        enabled: true,
        applies_only_to_agents: true,
        ip_ranges: ip_ranges
      }
    }
    put :update, construct_params(api_security: request_params)
    assert_response 400
    match_json([bad_request_error_pattern(:ip_ranges, :max_limit, name: 'whitelisted_ip.ip_ranges', max_value: 500)])
  ensure
    Account.any_instance.unstub(:whitelisted_ips_enabled?)
  end

  def test_update_whitelisted_ip_skips_if_disabled
    Account.any_instance.stubs(:whitelisted_ips_enabled?).returns(true)
    @request.env['CLIENT_IP'] = '111.11.00.110'
    whitelisted_ip = Account.current.whitelisted_ip || Account.current.build_whitelisted_ip(user_type: 2)
    whitelisted_ip.load_ip_info(@request.env['CLIENT_IP'])
    whitelisted_ip.attributes = {
      enabled: true,
      applies_only_to_agents: false,
      ip_ranges: [{ start_ip: '111.11.00.11', end_ip: '111.11.00.111' }]
    }.with_indifferent_access
    whitelisted_ip.save
    request_params = {
      whitelisted_ip: {
        enabled: false,
        applies_only_to_agents: true
      }
    }
    put :update, construct_params(api_security: request_params)
    assert_response 200
    whitelisted_ip.reload
    refute whitelisted_ip.enabled
    refute whitelisted_ip.applies_only_to_agents
  ensure
    Account.any_instance.unstub(:whitelisted_ips_enabled?)
    whitelisted_ip.destroy
  end

  def test_update_whitelisted_ip_without_feature
    Account.any_instance.stubs(:whitelisted_ips_enabled?).returns(false)
    @request.env['CLIENT_IP'] = '111.11.00.110'
    request_params = {
      whitelisted_ip: {
        enabled: true,
        applies_only_to_agents: true,
        ip_ranges: [{
          start_ip: '111.11.00.10',
          end_ip: '111.11.00.111'
        }]
      }
    }
    put :update, construct_params(api_security: request_params)
    assert_response 400
    match_json([bad_request_error_pattern(:whitelisted_ip, :require_feature_for_attribute, feature: 'whitelisted_ips', attribute: 'whitelisted_ip')])
  ensure
    Account.any_instance.unstub(:whitelisted_ips_enabled?)
  end

  def test_update_whitelisted_ip_current_ip_not_in_range_ip_v6
    Account.any_instance.stubs(:whitelisted_ips_enabled?).returns(true)
    @request.env['CLIENT_IP'] = '2001:db8:001f:ffff:ffff:ffff:ffff:ffff'
    request_params = {
      whitelisted_ip: {
        enabled: true,
        applies_only_to_agents: true,
        ip_ranges: [{
          start_ip: '1001:db8:001f:ffff:ffff:ffff:ffff:0000',
          end_ip: '1001:db8:001f:ffff:ffff:ffff:ffff:ffff'
        }]
      }
    }
    put :update, construct_params(api_security: request_params)
    assert_response 400
    match_json([bad_request_error_pattern('whitelisted_ip.base', 'Your current IP is not in the list of Ranges')])
  ensure
    Account.any_instance.unstub(:whitelisted_ips_enabled?)
  end

  def test_update_whitelisted_ip_not_in_range_ip_v6
    Account.any_instance.stubs(:whitelisted_ips_enabled?).returns(true)
    @request.env['CLIENT_IP'] = '2001:db8:001f:ffff:ffff:ffff:ffff:0001'
    request_params = {
      whitelisted_ip: {
        enabled: true,
        applies_only_to_agents: true,
        ip_ranges: [{
          start_ip: '2001:db8:001f:ffff:ffff:ffff:ffff:ffff',
          end_ip: '1001:db8:001f:ffff:ffff:ffff:ffff:ffff'
        }]
      }
    }
    put :update, construct_params(api_security: request_params)
    assert_response 400
    match_json([bad_request_error_pattern('whitelisted_ip.base', 'Your current IP is not in the list of Ranges')])
  ensure
    Account.any_instance.unstub(:whitelisted_ips_enabled?)
  end

  def test_update_whitelisted_ip_not_in_range
    Account.any_instance.stubs(:whitelisted_ips_enabled?).returns(true)
    @request.env['CLIENT_IP'] = '111.11.00.110'
    request_params = {
      whitelisted_ip: {
        enabled: true,
        applies_only_to_agents: true,
        ip_ranges: [{
          start_ip: '192.11.00.10',
          end_ip: '111.11.00.111'
        }]
      }
    }
    put :update, construct_params(api_security: request_params)
    assert_response 400
    match_json([bad_request_error_pattern('whitelisted_ip.base', 'Your current IP is not in the list of Ranges')])
  ensure
    Account.any_instance.unstub(:whitelisted_ips_enabled?)
  end

  def test_update_whitelisted_ip_current_ip_not_in_range
    Account.any_instance.stubs(:whitelisted_ips_enabled?).returns(true)
    @request.env['CLIENT_IP'] = '172.11.00.110'
    request_params = {
      whitelisted_ip: {
        enabled: true,
        applies_only_to_agents: true,
        ip_ranges: [{
          start_ip: '111.11.00.10',
          end_ip: '111.11.00.111'
        }]
      }
    }
    put :update, construct_params(api_security: request_params)
    assert_response 400
    match_json([bad_request_error_pattern('whitelisted_ip.base', 'Your current IP is not in the list of Ranges')])
  ensure
    Account.any_instance.unstub(:whitelisted_ips_enabled?)
  end

  def test_update_whitelisted_ip_current_ip_format_mismatch_ipv4
    Account.any_instance.stubs(:whitelisted_ips_enabled?).returns(true)
    @request.env['CLIENT_IP'] = '001:db8:001f:ffff:ffff:ffff:ffff:ffff'
    request_params = {
      whitelisted_ip: {
        enabled: true,
        applies_only_to_agents: true,
        ip_ranges: [{
          start_ip: '111.11.00.10',
          end_ip: '111.11.00.111'
        }]
      }
    }
    put :update, construct_params(api_security: request_params)
    assert_response 400
    match_json([bad_request_error_pattern('whitelisted_ip.base', 'Your current IP is not in the list of Ranges')])
  ensure
    Account.any_instance.unstub(:whitelisted_ips_enabled?)
  end

  def test_update_whitelisted_ip_current_ip_format_mismatch_ipv6
    Account.any_instance.stubs(:whitelisted_ips_enabled?).returns(true)
    @request.env['CLIENT_IP'] = '111.11.00.110'
    request_params = {
      whitelisted_ip: {
        enabled: true,
        applies_only_to_agents: true,
        ip_ranges: [{
          start_ip: '1001:db8:001f:ffff:ffff:ffff:ffff:0000',
          end_ip: '1001:db8:001f:ffff:ffff:ffff:ffff:ffff'
        }]
      }
    }
    put :update, construct_params(api_security: request_params)
    assert_response 400
    match_json([bad_request_error_pattern('whitelisted_ip.base', 'Your current IP is not in the list of Ranges')])
  ensure
    Account.any_instance.unstub(:whitelisted_ips_enabled?)
  end

  def test_update_whitelisted_ipv6_invalid_data
    Account.any_instance.stubs(:whitelisted_ips_enabled?).returns(true)
    @request.env['CLIENT_IP'] = '2001:db8:001f:ffff:ffff:ffff:ffff:0001'
    request_params = {
      whitelisted_ip: {
        enabled: true,
        applies_only_to_agents: true,
        ip_ranges: [{
          start_ip: 'xxxx:xxyyy:gggg:hhhh:oooo:pppp:qqqq:rrrr',
          end_ip: 'xxxx:xxyyy:gggg:hhhh:oooo:pppp:qqqq:rrrr'
        }]
      }
    }
    put :update, construct_params(api_security: request_params)
    assert_response 400
    match_json([bad_request_error_pattern('whitelisted_ip.base', 'Enter valid IP Address')])
  ensure
    Account.any_instance.unstub(:whitelisted_ips_enabled?)
  end

  def test_update_whitelisted_ip_current_ip_invalid_data
    Account.any_instance.stubs(:whitelisted_ips_enabled?).returns(true)
    @request.env['CLIENT_IP'] = '111.11.00.110'
    request_params = {
      whitelisted_ip: {
        enabled: true,
        applies_only_to_agents: true,
        ip_ranges: [{
          start_ip: '1000.1111.4000.500',
          end_ip: 'abc.1111.4000.500'
        }]
      }
    }
    put :update, construct_params(api_security: request_params)
    assert_response 400
    match_json([bad_request_error_pattern('whitelisted_ip.base', 'Enter valid IP Address')])
  ensure
    Account.any_instance.unstub(:whitelisted_ips_enabled?)
  end

  def test_update_set_secure_fields_when_toggle_not_enabled
    Account.current.stubs(:secure_fields_toggle_enabled?).returns(false)
    request_params = {
      secure_fields: true
    }
    put :update, construct_params(api_security: request_params)
    assert_response 400
    match_json([bad_request_error_pattern(:secure_fields, :require_feature_for_attribute, feature: 'secure_fields_toggle', attribute: 'secure_fields')])
  ensure
    Account.current.unstub(:secure_fields_toggle_enabled?)
  end

  def test_update_set_secure_fields_when_whitelisted_ips_feature_not_enabled
    Account.current.stubs(:secure_fields_toggle_enabled?).returns(true)
    Account.current.stubs(:whitelisted_ips_enabled?).returns(false)
    request_params = {
      secure_fields: true
    }
    put :update, construct_params(api_security: request_params)
    assert_response 400
    match_json([bad_request_error_pattern(:secure_fields, :action_restricted, action: 'enable secure_fields', reason: 'whitelisted_ip is not enabled')])
  ensure
    Account.current.unstub(:secure_fields_toggle_enabled?)
    Account.current.unstub(:whitelisted_ips_enabled?)
  end

  def test_update_set_secure_fields_when_whitelisted_ips_not_present
    Account.current.stubs(:secure_fields_toggle_enabled?).returns(true)
    Account.current.stubs(:whitelisted_ips_enabled?).returns(true)
    Account.current.stubs(:whitelisted_ip).returns(nil)
    request_params = {
      secure_fields: true
    }
    put :update, construct_params(api_security: request_params)
    assert_response 400
    match_json([bad_request_error_pattern(:secure_fields, :action_restricted, action: 'enable secure_fields', reason: 'whitelisted_ip is not enabled')])
  ensure
    Account.current.unstub(:secure_fields_toggle_enabled?)
    Account.current.unstub(:whitelisted_ips_enabled?)
    Account.current.unstub(:whitelisted_ip)
  end

  def test_update_set_secure_fields_when_whitelisted_ips_not_enabled
    Account.current.stubs(:secure_fields_toggle_enabled?).returns(true)
    Account.current.stubs(:whitelisted_ips_enabled?).returns(true)
    Account.current.stubs(:whitelisted_ip).returns(WhitelistedIp.new(enabled: false))
    request_params = {
      secure_fields: true
    }
    put :update, construct_params(api_security: request_params)
    assert_response 400
    match_json([bad_request_error_pattern(:secure_fields, :action_restricted, action: 'enable secure_fields', reason: 'whitelisted_ip is not enabled')])
  ensure
    Account.current.unstub(:secure_fields_toggle_enabled?)
    Account.current.unstub(:whitelisted_ips_enabled?)
    Account.current.unstub(:whitelisted_ip)
  end

  def test_update_set_secure_fields_when_whitelisted_ips_ip_ranges_empty
    Account.current.stubs(:secure_fields_toggle_enabled?).returns(true)
    Account.current.stubs(:whitelisted_ips_enabled?).returns(true)
    Account.current.stubs(:whitelisted_ip).returns(WhitelistedIp.new(enabled: true, ip_ranges: []))
    request_params = {
      secure_fields: true
    }
    put :update, construct_params(api_security: request_params)
    assert_response 400
    match_json([bad_request_error_pattern(:secure_fields, :action_restricted, action: 'enable secure_fields', reason: 'whitelisted_ip is not enabled')])
  ensure
    Account.current.unstub(:secure_fields_toggle_enabled?)
    Account.current.unstub(:whitelisted_ips_enabled?)
    Account.current.unstub(:whitelisted_ip)
  end

  def test_update_set_secure_fields_when_ticket_field_revamp_not_enabled
    Account.current.stubs(:secure_fields_toggle_enabled?).returns(true)
    Account.current.stubs(:whitelisted_ips_enabled?).returns(true)
    Account.current.stubs(:whitelisted_ip).returns(WhitelistedIp.new(whitelisted_ip_attributes))
    Account.current.stubs(:ticket_field_revamp_enabled?).returns(false)
    request_params = {
      secure_fields: true
    }
    put :update, construct_params(api_security: request_params)
    assert_response 400
    match_json([bad_request_error_pattern(:secure_fields, :require_feature_for_attribute, feature: 'ticket_field_revamp', attribute: 'secure_fields')])
  ensure
    Account.current.unstub(:secure_fields_toggle_enabled?)
    Account.current.unstub(:whitelisted_ips_enabled?)
    Account.current.unstub(:ticket_field_revamp_enabled?)
    Account.current.unstub(:whitelisted_ip)
  end

  def test_update_set_secure_fields
    Account.current.stubs(:secure_fields_toggle_enabled?).returns(true)
    Account.current.stubs(:whitelisted_ips_enabled?).returns(true)
    Account.current.stubs(:whitelisted_ip).returns(WhitelistedIp.new(whitelisted_ip_attributes))
    Account.current.stubs(:ticket_field_revamp_enabled?).returns(true)
    ::Vault::AccountWorker.jobs.clear
    request_params = {
      secure_fields: true
    }
    put :update, construct_params(api_security: request_params)
    assert_response 200
    assert_equal true, JSON.parse(response.body)['secure_fields']
    assert_equal 1, ::Vault::AccountWorker.jobs.size
    args = ::Vault::AccountWorker.jobs.first.deep_symbolize_keys[:args][0]
    assert_equal 'update', args[:action]
  ensure
    Account.current.unstub(:secure_fields_toggle_enabled?)
    Account.current.unstub(:whitelisted_ips_enabled?)
    Account.current.unstub(:whitelisted_ip)
    Account.current.unstub(:ticket_field_revamp_enabled?)
    ::Vault::AccountWorker.jobs.clear
  end

  def test_update_unset_secure_fields
    Account.current.stubs(:secure_fields_toggle_enabled?).returns(true)
    ::Vault::AccountWorker.jobs.clear
    request_params = {
      secure_fields: false
    }
    put :update, construct_params(api_security: request_params)
    assert_response 200
    assert_equal false, JSON.parse(response.body)['secure_fields']
    assert_equal 1, ::Vault::AccountWorker.jobs.size
    args = ::Vault::AccountWorker.jobs.first.deep_symbolize_keys[:args][0]
    assert_equal 'delete', args[:action]
  ensure
    Account.current.unstub(:secure_fields_toggle_enabled?)
    ::Vault::AccountWorker.jobs.clear
  end

  def test_update_disable_whitelisted_ip_when_secure_fields_enabled
    Account.current.stubs(:whitelisted_ips_enabled?).returns(true)
    Account.current.stubs(:secure_fields_enabled?).returns(true)
    @request.env['CLIENT_IP'] = '111.11.00.110'
    request_params = {
      whitelisted_ip: {
        enabled: false
      }
    }
    put :update, construct_params(api_security: request_params)
    assert_response 400
    match_json([bad_request_error_pattern(:whitelisted_ip, :action_restricted, action: 'disable whitelisted_ip', reason: 'secure_fields is enabled')])
  ensure
    Account.current.unstub(:whitelisted_ips_enabled?)
    Account.current.unstub(:secure_fields_enabled?)
  end

  def test_update_security_settings_with_invalid_param
    request_params = {
      input: 'wrong'
    }
    put :update, construct_params(api_security: request_params)
    assert_response 400
    match_json([bad_request_error_pattern(:input, :invalid_field, attribute: 'input')])
  end

  def test_update_sso
    Account.any_instance.stubs(:freshid_org_v2_enabled?).returns(false)
    Account.any_instance.stubs(:freshid_sso_sync_enabled?).returns(false)
    Account.any_instance.stubs(:sso_enabled?).returns(false)
    request_params = {
      sso: {
        enabled: true,
        type: 'simple',
        simple: {
          login_url: 'abc'
        }
      }
    }
    put :update, construct_params(api_security: request_params)
    assert_response 200
    assert Account.current.sso_enabled
    assert_equal request_params[:sso][:type], Account.current.current_sso_type
    assert_equal request_params[:sso][:simple][:login_url], Account.current.sso_options[:login_url]
  ensure
    Account.any_instance.unstub(:freshid_org_v2_enabled?)
    Account.any_instance.unstub(:freshid_sso_sync_enabled?)
    Account.any_instance.unstub(:sso_enabled?)
  end

  def test_update_sso_disable
    Account.any_instance.stubs(:freshid_org_v2_enabled?).returns(false)
    Account.any_instance.stubs(:freshid_sso_sync_enabled?).returns(false)
    @account.sso_enabled = true
    @account.save
    request_params = {
      sso: {
        enabled: false
      }
    }
    put :update, construct_params(api_security: request_params)
    assert_response 200
    refute Account.current.sso_enabled
  ensure
    Account.any_instance.unstub(:freshid_org_v2_enabled?)
    Account.any_instance.unstub(:freshid_sso_sync_enabled?)
  end

  def test_update_sso_disable_with_freshid_sso_sync_enabled
    Account.any_instance.stubs(:freshid_org_v2_enabled?).returns(false)
    Account.any_instance.stubs(:freshid_sso_sync_enabled?).returns(true)
    @account.sso_enabled = true
    sso_options = {
      sso_type: 'simple',
      login_url: 'login_url'
    }
    @account.sso_options = HashWithIndifferentAccess.new(sso_options)
    @account.save
    request_params = {
      sso: {
        enabled: false
      }
    }
    put :update, construct_params(api_security: request_params)
    assert_response 200
    refute Account.current.sso_enabled
  ensure
    Account.any_instance.unstub(:freshid_org_v2_enabled?)
    Account.any_instance.unstub(:freshid_sso_sync_enabled?)
  end

  def test_update_sso_logout_url
    Account.any_instance.stubs(:freshdesk_sso_configurable?).returns(true)
    sso_options_backup = Account.current.sso_options
    sso_options = {
      sso_type: 'simple',
      login_url: 'login_url'
    }
    @account.sso_options = HashWithIndifferentAccess.new(sso_options)
    @account.save
    request_params = {
      sso: {
        enabled: true,
        simple: {
          logout_url: 'logout_url'
        }
      }
    }
    put :update, construct_params(api_security: request_params)
    assert_response 200
    assert Account.current.sso_enabled
    assert_equal sso_options[:login_url], Account.current.sso_options[:login_url]
    assert_equal request_params[:sso][:simple][:logout_url], Account.current.sso_options[:logout_url]
  ensure
    Account.any_instance.unstub(:freshdesk_sso_configurable?)
    @account.sso_options = sso_options_backup
    @account.save
  end

  def test_update_sso_disable_with_freshid_and_freshid_sso_sync
    Account.any_instance.stubs(:freshid_sso_sync_enabled?).returns(true)
    Account.any_instance.stubs(:freshid_sso_enabled?).returns(true)
    sso_options_backup = Account.current.sso_options
    sso_options = {
      sso_type: 'simple',
      login_url: 'login_url',
      logout_url: 'logout_url'
    }
    @account.sso_options = HashWithIndifferentAccess.new(sso_options)
    @account.save
    request_params = {
      sso: {
        enabled: false
      }
    }
    put :update, construct_params(api_security: request_params)
    assert_response 200
    refute Account.current.sso_enabled
    refute Account.current.sso_options.key?(:sso_type)
    refute Account.current.sso_options.key?(:login_url)
    refute Account.current.sso_options.key?(:logout_url)
  ensure
    Account.any_instance.unstub(:freshid_sso_sync_enabled?)
    Account.any_instance.unstub(:freshid_sso_enabled?)
    @account.sso_options = sso_options_backup
    @account.save
  end

  def test_update_simple_sso_with_oauth2_as_current_type
    Account.any_instance.stubs(:freshdesk_sso_configurable?).returns(true)
    sso_options_backup = Account.current.sso_options
    sso_options = {
      sso_type: 'oauth2',
      agent_oauth2: true,
      customer_oauth2: true,
      agent_oauth2_config: {},
      customer_oauth2_config: {}
    }
    @account.sso_options = HashWithIndifferentAccess.new(sso_options)
    @account.save
    request_params = {
      sso: {
        enabled: true,
        type: 'simple',
        simple: {
          login_url: 'simple.login'
        }
      }
    }
    put :update, construct_params(api_security: request_params)
    assert_response 200
    assert Account.current.is_simple_sso?
    refute Account.current.oauth2_sso_enabled?
    refute Account.current.sso_options.key?(:agent_oauth2_config)
    refute Account.current.sso_options.key?(:customer_oauth2_config)
  ensure
    Account.any_instance.unstub(:freshdesk_sso_configurable?)
    @account.sso_options = sso_options_backup
    @account.save
  end

  def test_update_simple_sso_with_freshid_saml_as_current_type
    Account.any_instance.stubs(:freshdesk_sso_configurable?).returns(true)
    sso_options_backup = Account.current.sso_options
    sso_options = {
      sso_type: 'freshid_saml',
      agent_freshid_saml: true,
      agent_freshid_saml_config: {},
      customer_freshid_saml: true,
      customer_freshid_saml_config: {}
    }
    @account.sso_options = HashWithIndifferentAccess.new(sso_options)
    @account.save
    request_params = {
      sso: {
        enabled: true,
        type: 'simple',
        simple: {
          login_url: 'simple.login'
        }
      }
    }
    put :update, construct_params(api_security: request_params)
    assert_response 200
    assert Account.current.is_simple_sso?
    refute Account.current.freshid_saml_sso_enabled?
    refute Account.current.sso_options.key?(:agent_freshid_saml_config)
    refute Account.current.sso_options.key?(:customer_freshid_saml_config)
  ensure
    Account.any_instance.unstub(:freshdesk_sso_configurable?)
    @account.sso_options = sso_options_backup
    @account.save
  end

  def test_update_disable_sso_when_freshid_integration_enabled_and_freshdesk_sso_enabled
    Account.any_instance.stubs(:coexist_account?).returns(true)
    Account.any_instance.stubs(:freshdesk_sso_configurable?).returns(true)
    request_params = {
      sso: {
        enabled: false
      }
    }
    put :update, construct_params(api_security: request_params)
    assert_response 200
    refute Account.current.sso_enabled
  ensure
    Account.any_instance.unstub(:coexist_account?)
    Account.any_instance.unstub(:freshdesk_sso_configurable?)
  end

  def test_update_sso_disabled_freshid_account_v2_migration
    Freshid::AgentsMigration.jobs.clear
    Account.any_instance.stubs(:freshdesk_sso_configurable?).returns(true)
    Account.any_instance.stubs(:freshid_integration_signup_allowed?).returns(true)
    Account.any_instance.stubs(:freshid_migration_not_in_progress?).returns(true)
    Account.any_instance.stubs(:freshid_v2_signup_allowed?).returns(true)
    Account.any_instance.stubs(:freshid_integration_enabled?).returns(false)
    @account.sso_enabled = true
    @account.save
    request_params = {
      sso: {
        enabled: false
      }
    }
    put :update, construct_params(api_security: request_params)
    assert_response 200
    refute Account.current.sso_enabled?
    assert_equal 1, Freshid::V2::AgentsMigration.jobs.size
  ensure
    Account.any_instance.unstub(:freshid_integration_signup_allowed?)
    Account.any_instance.unstub(:freshid_migration_not_in_progress?)
    Account.any_instance.unstub(:freshid_v2_signup_allowed?)
    Account.any_instance.unstub(:freshdesk_sso_configurable?)
    Account.any_instance.unstub(:freshid_integration_enabled?)
    @account.sso_enabled = false
    @account.save
  end

  def test_update_sso_disabled_freshid_account_v1_migration
    Freshid::AgentsMigration.jobs.clear
    Account.any_instance.stubs(:freshdesk_sso_configurable?).returns(true)
    Account.any_instance.stubs(:freshid_integration_signup_allowed?).returns(true)
    Account.any_instance.stubs(:freshid_migration_not_in_progress?).returns(true)
    Account.any_instance.stubs(:freshid_v2_signup_allowed?).returns(false)
    Account.any_instance.stubs(:freshid_integration_enabled?).returns(false)
    @account.sso_enabled = true
    @account.save
    request_params = {
      sso: {
        enabled: false
      }
    }
    put :update, construct_params(api_security: request_params)
    assert_response 200
    refute Account.current.sso_enabled
    assert_equal 1, Freshid::AgentsMigration.jobs.size
  ensure
    Account.any_instance.unstub(:freshid_integration_signup_allowed?)
    Account.any_instance.unstub(:freshid_migration_not_in_progress?)
    Account.any_instance.unstub(:freshid_v2_signup_allowed?)
    Account.any_instance.unstub(:freshdesk_sso_configurable?)
    Account.any_instance.unstub(:freshid_integration_enabled?)
    @account.sso_enabled = false
    @account.save
  end

  def test_update_sso_disabled_freshid_account_migration_not_allowed
    Freshid::AgentsMigration.jobs.clear
    Account.any_instance.stubs(:freshdesk_sso_configurable?).returns(true)
    Account.any_instance.stubs(:freshid_integration_signup_allowed?).returns(false)
    Account.any_instance.stubs(:freshid_migration_not_in_progress?).returns(true)
    Account.any_instance.stubs(:freshid_v2_signup_allowed?).returns(false) # signup not allowed
    Account.any_instance.stubs(:freshid_integration_enabled?).returns(false)
    @account.sso_enabled = true
    @account.save
    request_params = {
      sso: {
        enabled: false
    }
    }
    put :update, construct_params(api_security: request_params)
    assert_response 200
    refute Account.current.sso_enabled
    assert_equal 0, Freshid::AgentsMigration.jobs.size
  ensure
    Account.any_instance.unstub(:freshid_integration_signup_allowed?)
    Account.any_instance.unstub(:freshid_migration_not_in_progress?)
    Account.any_instance.unstub(:freshid_v2_signup_allowed?)
    Account.any_instance.unstub(:freshdesk_sso_configurable?)
    Account.any_instance.unstub(:freshid_integration_enabled?)
    @account.sso_enabled = false
    @account.save
  end

  def test_update_sso_without_login_url
    Account.any_instance.stubs(:freshdesk_sso_configurable?).returns(true)
    request_params = {
      sso: {
        enabled: true,
        type: 'simple',
        simple: {
          logout_url: 'logout_url'
        }
      }
    }
    put :update, construct_params(api_security: request_params)
    assert_response 400
    match_json([bad_request_error_pattern('sso_options', 'Please provide a valid login URL')])
  ensure
    Account.any_instance.unstub(:freshdesk_sso_configurable?)
  end

  def test_update_sso_saml_without_login_url
    Account.any_instance.stubs(:freshdesk_sso_configurable?).returns(true)
    request_params = {
      sso: {
        enabled: true,
        type: 'saml',
        saml: {
          logout_url: 'logout_url',
          saml_cert_fingerprint: 'cert'
        }
      }
    }
    put :update, construct_params(api_security: request_params)
    assert_response 400
    match_json([bad_request_error_pattern('sso_options', 'Please provide a valid SAML login URL')])
  ensure
    Account.any_instance.unstub(:freshdesk_sso_configurable?)
  end

  def test_update_sso_saml_without_saml_cert_fingerprint
    Account.any_instance.stubs(:freshdesk_sso_configurable?).returns(true)
    request_params = {
      sso: {
        enabled: true,
        type: 'saml',
        saml: {
          logout_url: 'logout_url',
          login_url: 'login_url'
        }
      }
    }
    put :update, construct_params(api_security: request_params)
    assert_response 400
    match_json([bad_request_error_pattern('sso_options', 'Please provide a valid SAML Certificate Fingerprint')])
  ensure
    Account.any_instance.unstub(:freshdesk_sso_configurable?)
  end

  def test_update_sso_with_freshid_v2
    Account.any_instance.stubs(:freshdesk_sso_configurable?).returns(false)
    request_params = {
      sso: {
        enabled: true,
        type: 'simple',
        simple: {
          login_url: 'abc'
        }
      }
    }
    put :update, construct_params(api_security: request_params)
    assert_response 400
    match_json([bad_request_error_pattern(:sso, :action_restricted, action: 'sso configuration', reason: 'account is in freshid v2')])
  ensure
    Account.any_instance.unstub(:freshdesk_sso_configurable?)
  end

  def test_update_simple_sso_with_freshid_integration_enabled_and_freshdesk_sso_enabled
    Account.any_instance.stubs(:coexist_account?).returns(true)
    request_params = {
      sso: {
        enabled: true,
        type: 'simple',
        simple: {
          login_url: 'abc'
        }
      }
    }
    put :update, construct_params(api_security: request_params)
    assert_response 400
    match_json([bad_request_error_pattern(:sso, :action_restricted, action: 'sso configuration', reason: 'freshid is integrated and freshdesk sso is configured')])
  ensure
    Account.any_instance.unstub(:coexist_account?)
  end

  def test_update_sso_with_freshid_migration_inprogress
    Account.any_instance.stubs(:freshid_migration_in_progress?).returns(true)
    request_params = {
      sso: {
        enabled: false
      }
    }
    put :update, construct_params(api_security: request_params)
    assert_response 400
    match_json([bad_request_error_pattern(:sso, :action_restricted, action: 'sso configuration', reason: 'freshid migration is inprogress')])
  ensure
    Account.any_instance.unstub(:freshid_migration_in_progress?)
  end

  def test_update_allow_iframe
    request_params = {
      allow_iframe_embedding: true
    }
    put :update, construct_params(api_security: request_params)
    assert_response 200
    assert_equal true, Account.current.allow_iframe_embedding
  end

  def test_update_deny_iframe_off
    request_params = {
      allow_iframe_embedding: false
    }
    put :update, construct_params(api_security: request_params)
    assert_response 200
    assert_equal false, Account.current.allow_iframe_embedding
  end

  def test_update_redaction
    Account.any_instance.stubs(:redaction_enabled?).returns(true)
    request_params = {
      redaction: {
        credit_card_number: true
      }
    }
    put :update, construct_params(api_security: request_params)
    assert_response 200
    assert_equal true, Account.current.redaction['credit_card_number']
  ensure
    Account.any_instance.unstub(:redaction_enabled?)
  end

  def test_update_redaction_turn_off
    Account.any_instance.stubs(:redaction_enabled?).returns(true)
    request_params = {
      redaction: {
        credit_card_number: false
      }
    }
    put :update, construct_params(api_security: request_params)
    assert_response 200
    assert_equal false, Account.current.redaction['credit_card_number']
  ensure
    Account.any_instance.unstub(:redaction_enabled?)
  end

  def test_update_redaction_without_feature
    Account.any_instance.stubs(:redaction_enabled?).returns(false)
    request_params = {
      redaction: {
        credit_card_number: true
      }
    }
    put :update, construct_params(api_security: request_params)
    assert_response 400
    match_json([bad_request_error_pattern(:redaction, :require_feature_for_attribute, feature: 'redaction', attribute: 'redaction')])
  ensure
    Account.any_instance.unstub(:redaction_enabled?)
  end

  private

    def stub_account
      Account.current.stubs(:whitelisted_ips_enabled?).returns(true)
      Account.current.stubs(:help_widget_enabled?).returns(true)
      Account.current.stubs(:notification_emails).returns(notification_emails)
      Account.current.stubs(:freshid_integration_enabled?).returns(false)
      Account.current.stubs(:single_session_per_user_toggle_enabled?).returns(true)
      Account.current.stubs(:single_session_per_user_enabled?).returns(true)
      Account.current.stubs(:idle_session_timeout_enabled?).returns(true)
      Account.current.stubs(:idle_session_timeout).returns(900)
      Account.current.stubs(:secure_fields_toggle_enabled?).returns(true)
      Account.current.stubs(:secure_fields_enabled?).returns(true)
      create_whitelisted_ip(whitelisted_ip_attributes)
      create_password_policy(agent_password_policy_attributes)
    end

    def unstub_account
      Account.current.unstub(:whitelisted_ips_enabled?)
      Account.current.unstub(:help_widget_enabled?)
      Account.current.unstub(:notification_emails)
      Account.current.unstub(:freshid_integration_enabled?)
      Account.current.unstub(:single_session_per_user_toggle_enabled?)
      Account.current.unstub(:single_session_per_user_enabled?)
      Account.current.unstub(:idle_session_timeout)
      Account.current.unstub(:idle_session_timeout_enabled?)
      Account.current.unstub(:secure_fields_toggle_enabled?)
      Account.current.unstub(:secure_fields_enabled?)
      destroy_password_policy
      destroy_whitelisted_ip
    end

    def create_whitelisted_ip(whitelisted_ip_attributes)
      Account.current.whitelisted_ip_attributes = whitelisted_ip_attributes
      Account.current.whitelisted_ip.load_ip_info(User.current.current_login_ip)
      Account.current.whitelisted_ip.save
    end

    def create_password_policy(password_policy_attributes)
      Account.current.build_agent_password_policy(password_policy_attributes)
      Account.current.agent_password_policy.save
    end

    def destroy_whitelisted_ip
      Account.current.whitelisted_ip.try(:destroy)
    end

    def destroy_password_policy
      Account.current.agent_password_policy.try(:destroy)
    end
end
