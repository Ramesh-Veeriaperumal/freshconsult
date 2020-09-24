require_relative '../../test_helper'
require Rails.root.join('test', 'api', 'helpers', 'admin', 'security_test_helper.rb')

class Admin::ApiSecurityControllerTest < ActionController::TestCase
  include Admin::SecurityTestHelper
  include UsersHelper

  def test_whitelisted_ips_not_enabled
    Account.any_instance.stubs(:whitelisted_ips_enabled?).returns(false)
    get :show, controller_params
    assert_response 200
    assert_nil JSON.parse(response.body)['whitelisted_ip']
  ensure
    Account.any_instance.unstub(:whitelisted_ips_enabled?)
  end

  def test_whitelisted_ip_enabled
    Account.any_instance.stubs(:whitelisted_ips_enabled?).returns(true)
    Account.current.stubs(:whitelisted_ip).returns(nil)
    get :show, controller_params
    assert_response 200
    assert_equal whitelisted_ip_not_configured, JSON.parse(response.body)['whitelisted_ip']
  ensure
    Account.any_instance.unstub(:whitelisted_ips_enabled?)
  end

  def test_help_widget_not_enabled
    Account.any_instance.stubs(:help_widget_enabled?).returns(false)
    get :show, controller_params
    assert_response 200
    assert_nil JSON.parse(response.body)['help_widget']
  ensure
    Account.any_instance.unstub(:help_widget_enabled?)
  end

  def test_custom_password_policy_not_enabled
    Account.any_instance.stubs(:custom_password_policy_enabled?).returns(false)
    get :show, controller_params
    assert_response 200
    assert_nil JSON.parse(response.body)['agent_password_policy']
    assert_nil JSON.parse(response.body)['contact_password_policy']
  ensure
    Account.any_instance.unstub(:custom_password_policy_enabled?)
  end

  def test_password_policy_with_freshid_integration_enabled
    Account.any_instance.stubs(:freshid_integration_enabled?).returns(true)
    get :show, controller_params
    assert_response 200
    assert_nil JSON.parse(response.body)['agent_password_policy']
    assert_equal password_policy.stringify_keys, JSON.parse(response.body)['contact_password_policy']
  ensure
    Account.any_instance.unstub(:freshid_integration_enabled?)
  end

  def test_account_current_ip
    get :show, controller_params
    assert_response 200
    assert_equal request.remote_ip, response.api_meta[:current_ip]
  end

  def test_account_current_ip_when_whitelisted_ip_disabled
    Account.any_instance.stubs(:whitelisted_ips_enabled?).returns(false)
    get :show, controller_params
    assert_response 200
    assert_nil response.api_meta[:current_ip]
  ensure
    Account.any_instance.unstub(:whitelisted_ips_enabled?)
  end

  def test_account_freshid_migration_not_in_process
    get :show, controller_params(version: 'private')
    assert_response 200
    assert_equal false, response.api_meta[:freshid_migration_in_progress]
  end

  def test_account_freshid_migration_in_process
    Account.current.stubs(:freshid_migration_in_progress?).returns(true)
    get :show, controller_params(version: 'private')
    assert_response 200
    assert_equal true, response.api_meta[:freshid_migration_in_progress]
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

  def test_security_index_public_api
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

  def test_security_index_private_api
    stub_account
    get :show, controller_params(version: 'private')
    assert_response 200
    match_json(security_index_api_response_pattern)
  ensure
    unstub_account
  end

  def test_security_index_private_api_in_non_freshid_v2_accounts_saml
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

  def test_security_index_private_api_in_non_freshid_v2_accounts_simple_sso
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

  def test_security_index_private_api_in_oauth2_accounts
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

  def test_security_index_private_api_in_freshid_saml_accounts
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

  def test_security_index_private_api_in_freshid_v2_sso
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
    match_json([bad_request_error_pattern(:agent_password_policy, :unwanted_feature_for_attribute, feature: 'freshid', attribute: 'agent_password_policy')])
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
    match_json([bad_request_error_pattern(:agent_password_policy, :unwanted_feature_for_attribute, feature: 'freshid_org_v2', attribute: 'agent_password_policy')])
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
    Account.current.whitelisted_ip.destroy
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
    Account.current.whitelisted_ip.destroy
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

  def test_update_security_settings_with_invalid_param
    request_params = {
      input: 'wrong'
    }
    put :update, construct_params(api_security: request_params)
    assert_response 400
    match_json([bad_request_error_pattern(:input, :invalid_field, attribute: 'input')])
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

  private

    def stub_account
      Account.current.stubs(:whitelisted_ips_enabled?).returns(true)
      Account.current.stubs(:help_widget_enabled?).returns(true)
      Account.current.stubs(:notification_emails).returns(notification_emails)
      Account.current.stubs(:freshid_integration_enabled?).returns(false)
      create_whitelisted_ip(whitelisted_ip)
      create_password_policy(agent_password_policy)
    end

    def unstub_account
      Account.current.unstub(:whitelisted_ips_enabled?)
      Account.any_instance.unstub(:help_widget_enabled?)
      Account.current.unstub(:notification_emails)
      Account.current.unstub(:freshid_integration_enabled?)
      destroy_password_policy
      destroy_whitelisted_ip
    end

    def create_whitelisted_ip(whitelisted_ip)
      Account.current.whitelisted_ip_attributes = whitelisted_ip
      Account.current.whitelisted_ip.load_ip_info(User.current.current_login_ip)
      Account.current.whitelisted_ip.save
    end

    def create_password_policy(password_policy)
      Account.current.build_agent_password_policy(password_policy)
      Account.current.agent_password_policy.save
    end

    def destroy_whitelisted_ip
      Account.current.whitelisted_ip.try(:destroy)
    end

    def destroy_password_policy
      Account.current.agent_password_policy.try(:destroy)
    end
end
