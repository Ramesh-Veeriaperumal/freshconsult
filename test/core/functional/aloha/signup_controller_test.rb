require_relative '../../test_helper'
require 'webmock/minitest'

class Aloha::SignupControllerTest < ActionController::TestCase
  include AlohaSignupTestHelper
  def setup
    super
    before_all
  end

  def before_all
    @account = Account.first.make_current
    unless @account.organisation.present?
      org = create_organisation(12_345, 'test.freshworks.com')
      create_organisation_account_mapping(org.id)
      update_bundle_information('12345', 'support360')
    end
  end

  def test_freshchat_account_record_create
    Account.stubs(:current).returns(@account)
    @account.freshchat_account.try(:destroy)
    params = aloha_callback_params
    params[:product_name] = 'freshchat'
    params[:account][:domain] = 'test.freshchat.com'
    post :callback, params
    assert_response 200
    assert JSON.parse(response.body)['message'] == "#{params[:product_name]} record created successfully"
  end

  def test_kbase_omni_bundle_enabled_success_after_fchat_record_created
    params = aloha_callback_params
    params[:product_name] = 'freshchat'
    params[:account][:domain] = 'test.freshchat.com'

    stub_response = { enabled_features: ['kbase_omni_bundle'] }
    app_id = params[:misc][:userInfoList][0][:appId]
    freshchat_url = Freshchat::Account::CONFIG[:apiHostUrl]
    fc_feature_api = stub_request(:put, "#{freshchat_url}/v2/features").to_return(headers: { 'Content-Type' => 'application/json' }, status: 200, body: stub_response.to_json)
    fc_token_update_api = stub_request(:put, "#{freshchat_url}/v2/omnichannel-integration/#{app_id}").to_return(headers: { 'Content-Type' => 'application/json' }, status: 200)

    Account.stubs(:current).returns(@account)
    Account.current.launch(:launch_kbase_omni_bundle)

    @account.freshchat_account.try(:destroy)
    post :callback, params
    assert_response 200
    assert JSON.parse(response.body)['message'] == "#{params[:product_name]} record created successfully"
    assert Account.current.launched?(:kbase_omni_bundle)
  ensure
    Account.current.rollback(:launch_kbase_omni_bundle)
    remove_request_stub(fc_feature_api)
    remove_request_stub(fc_token_update_api)
  end

  def test_kbase_omni_bundle_enabled_failure_after_fchat_record_created
    params = aloha_callback_params
    params[:product_name] = 'freshchat'
    params[:account][:domain] = 'test.freshchat.com'

    stub_response = { enabled_features: [] }
    app_id = params[:misc][:userInfoList][0][:appId]
    freshchat_url = Freshchat::Account::CONFIG[:apiHostUrl]
    fc_feature_api = stub_request(:put, "#{freshchat_url}/v2/features").to_return(headers: { 'Content-Type' => 'application/json' }, status: 200, body: stub_response.to_json)
    fc_token_update_api = stub_request(:put, "#{freshchat_url}/v2/omnichannel-integration/#{app_id}").to_return(headers: { 'Content-Type' => 'application/json' }, status: 200)

    Account.stubs(:current).returns(@account)
    Account.current.launch(:launch_kbase_omni_bundle)
    Account.current.rollback(:kbase_omni_bundle)

    @account.freshchat_account.try(:destroy)
    post :callback, params
    assert_response 200
    assert JSON.parse(response.body)['message'] == "#{params[:product_name]} record created successfully"
    assert_not Account.current.launched?(:kbase_omni_bundle)
  ensure
    Account.current.rollback(:launch_kbase_omni_bundle)
    remove_request_stub(fc_feature_api)
    remove_request_stub(fc_token_update_api)
  end

  def test_freshcaller_account_record_create
    Account.stubs(:current).returns(@account)
    @account.freshcaller_account.try(:destroy)
    params = aloha_callback_params
    params[:product_name] = 'freshcaller'
    params[:account][:domain] = 'test.freshcaller.com'
    post :callback, params
    assert_response 200
    assert JSON.parse(response.body)['message'] == "#{params[:product_name]} record created successfully"
    assert_equal true, @account.freshcaller_enabled?
    assert_not_nil @account.account_managers.first.agent.freshcaller_agent
  end

  def test_bundle_id_mismatch
    Account.stubs(:current).returns(@account)
    @account.freshchat_account.try(:destroy)
    params = aloha_callback_params
    params[:bundle_id] = '5678'
    post :callback, params
    assert_response 500
    assert JSON.parse(response.body)['message'] == 'Bundle id/name mismatch'
  end

  def test_bundle_name_mismatch
    Account.stubs(:current).returns(@account)
    @account.freshchat_account.try(:destroy)
    params = aloha_callback_params
    params[:bundle_name] = 'dummy'
    post :callback, params
    assert_response 500
    assert JSON.parse(response.body)['message'] == 'Bundle id/name mismatch'
  end

  def test_wrong_seeder_product_create
    Account.stubs(:current).returns(@account)
    @account.freshchat_account.try(:destroy)
    params = aloha_callback_params
    params[:product_name] = 'freshbuddy'
    post :callback, params
    assert_response 500
    assert JSON.parse(response.body)['message'] == 'Invalid seeder product name'
  end

  def test_duplicate_freshchat_account_record_create
    Account.stubs(:current).returns(@account)
    @account.freshchat_account.try(:destroy)
    params = aloha_callback_params
    post :callback, params
    post :callback, params
    assert_response 500
    assert JSON.parse(response.body)['message'] == "#{params[:product_name]} entry already present for this freshdesk account"
  end

  def test_duplicate_freshcaller_account_record_create
    Account.stubs(:current).returns(@account)
    @account.freshcaller_account.try(:destroy)
    params = aloha_callback_params
    params[:product_name] = 'freshcaller'
    post :callback, params
    post :callback, params
    assert_response 500
    assert JSON.parse(response.body)['message'] == "#{params[:product_name]} entry already present for this freshdesk account"
  end

  def test_missing_account_domain
    Account.stubs(:current).returns(@account)
    @account.freshchat_account.try(:destroy)
    params = aloha_callback_params
    params[:account].delete(:domain)
    post :callback, params
    assert_response 500
  end
end 
