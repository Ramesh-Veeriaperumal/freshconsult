require_relative '../../../api/test_helper'
['dkim_test_helper.rb'].each { |file| require Rails.root.join("test/lib/helpers/#{file}") }
class Admin::DkimConfigurationsControllerTest < ActionController::TestCase
  include EmailMailboxTestHelper
  include DkimTestHelper

  def test_show_domains_with_verified_email_configs
    @verified_email_config = create_email_config(support_email: 'test@fresh.com')
    make_email_config_active(@verified_email_config)
    @unverified_email_config = create_email_config(active: false, support_email: 'test@test2.com')
    active_domains = @account.outgoing_email_domain_categories.find_by_email_domain('fresh.com')
    get :index
    assert_response 200
    assert_equal true, response.body.include?('fresh.com')
    assert_equal false, response.body.include?('test2.com')
  ensure
    @verified_email_config.destroy
    @unverified_email_config.destroy
  end

  def test_dkim_configurations_index_with_feature
    @verified_email_config = create_email_config(support_email: 'test@fresh.com')
    make_email_config_active(@verified_email_config)
    @verified_email_config2 = create_email_config(support_email: 'test2@fresh2.com')
    make_email_config_active(@verified_email_config2)
    active_domain = @account.outgoing_email_domain_categories.find_by_email_domain('fresh.com')
    change_domain_status(active_domain, 2)
    non_configured_domain = @account.outgoing_email_domain_categories.find_by_email_domain('fresh2.com')
    change_domain_status(non_configured_domain, 0)
    Account.any_instance.stubs(:launched?).returns(true)
    HttpRequestProxy.any_instance.stubs(:fetch_using_req_params).returns(status: 200, text: email_service_response_hash)
    get :index
    assert_response 200
    assert_equal true, response.body.include?('fresh.com')
    assert_equal true, response.body.include?('fresh2.com')
    assert_equal 1, response.body.scan('Configure').count
    assert_equal 0, response.body.scan('Unverified').count
    assert_equal 1, response.body.scan('dkim-table-wraper').count
  ensure
    @verified_email_config.destroy
    @verified_email_config2.destroy
    Account.any_instance.unstub(:launched?)
    HttpRequestProxy.any_instance.unstub(:fetch_using_req_params)
  end

  def test_dkim_configurations_index_without_feature
    @verified_email_config = create_email_config(support_email: 'test@fresh.com')
    make_email_config_active(@verified_email_config)
    @verified_email_config2 = create_email_config(support_email: 'test2@fresh2.com')
    make_email_config_active(@verified_email_config2)
    Account.any_instance.stubs(:launched?).returns(false)
    get :index
    assert_response 200
    assert_equal true, response.body.include?('fresh.com')
    assert_equal true, response.body.include?('fresh2.com')
    assert_equal 2, response.body.scan('Configure').count
  ensure
    @verified_email_config.destroy
    @verified_email_config2.destroy
    Account.any_instance.unstub(:launched?)
  end

  def test_dkim_configurations_index_with_failure_response
    @verified_email_config = create_email_config(support_email: 'test@fresh.com')
    make_email_config_active(@verified_email_config)
    @verified_email_config2 = create_email_config(support_email: 'test2@fresh2.com')
    make_email_config_active(@verified_email_config2)
    active_domain = @account.outgoing_email_domain_categories.find_by_email_domain('fresh.com')
    change_domain_status(active_domain, 2)
    non_configured_domain = @account.outgoing_email_domain_categories.find_by_email_domain('fresh2.com')
    change_domain_status(non_configured_domain, 0)
    Account.any_instance.stubs(:launched?).returns(true)
    HttpRequestProxy.any_instance.stubs(:fetch_using_req_params).returns(status: 503, text: email_service_failure_hash)
    get :index
    assert_response 200
    assert_equal true, response.body.include?('fresh.com')
    assert_equal true, response.body.include?('fresh2.com')
    assert_equal true, response.body.include?('Error fetching DNS settings. Please try again later.')
    assert_equal 2, response.body.scan('Configure').count
    assert_equal 0, response.body.scan('Unverified').count
    assert_equal 0, response.body.scan('dkim-table-wraper').count
  ensure
    @verified_email_config.destroy
    @verified_email_config2.destroy
    Account.any_instance.unstub(:launched?)
    HttpRequestProxy.any_instance.unstub(:fetch_using_req_params)
  end

  def test_dkim_configure_with_feature
    @verified_email_config = create_email_config(support_email: 'test@fresh.com')
    make_email_config_active(@verified_email_config)
    Account.any_instance.stubs(:launched?).returns(true)
    HttpRequestProxy.any_instance.stubs(:fetch_using_req_params).returns(status: 200, text: email_service_configure_hash)
    non_configured_domain1 = @account.outgoing_email_domain_categories.find_by_email_domain('fresh.com')
    change_domain_status(non_configured_domain1, 0)
    post :create, {id: non_configured_domain1.id}
    assert_response 200
    assert_equal true, response.body.include?('fresh.com')
    assert_equal 1, response.body.scan('Unverified').count
    assert_equal 1, response.body.scan('dkim-table-wraper').count
  ensure
    @verified_email_config.destroy
    Account.any_instance.unstub(:launched?)
    HttpRequestProxy.any_instance.unstub(:fetch_using_req_params)
  end

  def test_dkim_configure_with_error_response
    @verified_email_config = create_email_config(support_email: 'test@fresh.com')
    make_email_config_active(@verified_email_config)
    Account.any_instance.stubs(:launched?).returns(true)
    HttpRequestProxy.any_instance.stubs(:fetch_using_req_params).returns(status: 500, text: email_service_failure_hash)
    non_configured_domain = @account.outgoing_email_domain_categories.find_by_email_domain('fresh.com')
    change_domain_status(non_configured_domain, 0)
    post :create, {id: non_configured_domain.id}
    assert_response 200
    assert_equal true, response.body.include?('Cannot configure DKIM settings. Please try again later')
    assert_equal 1, response.body.scan('Configure').count
    assert_equal 0, response.body.scan('Unverified').count
    assert_equal 0, response.body.scan('dkim-table-wraper').count
  ensure
    @verified_email_config.destroy
    Account.any_instance.unstub(:launched?)
    HttpRequestProxy.any_instance.unstub(:fetch_using_req_params)
  end

  def test_dkim_configure_without_feature
    @verified_email_config = create_email_config(support_email: 'test@fresh.com')
    make_email_config_active(@verified_email_config)
    Account.any_instance.stubs(:launched?).returns(false)
    Dkim::ConfigureDkimRecord.any_instance.stubs(:sendgrid_verified_domain?).returns(false)
    Dkim::ConfigureDkimRecord.any_instance.stubs(:make_api).returns({:record_1 => sg_response_1, :record_2 => sg_response_2})
    Dkim::ConfigureDkimRecord.any_instance.stubs(:request_configure).returns({:record_1 => sg_response_1, :record_2 => sg_response_2})
    Dkim::ConfigureDkimRecord.any_instance.stubs(:add_dns_records_to_aws).returns(nil)
    non_configured_domain = @account.outgoing_email_domain_categories.find_by_email_domain('fresh.com')
    change_domain_status(non_configured_domain, 0)
    post :create, {id: non_configured_domain.id}
    assert_response 200
    assert_equal true, response.body.include?('fresh.com')
    assert_equal 1, response.body.scan('Unverified').count
    assert_equal 1, response.body.scan('dkim-table-wraper').count
  ensure
    @verified_email_config.destroy
    Account.any_instance.unstub(:launched?)
    Dkim::ConfigureDkimRecord.any_instance.unstub(:sendgrid_verified_domain?)
    Dkim::ConfigureDkimRecord.any_instance.unstub(:make_api)
    Dkim::ConfigureDkimRecord.any_instance.unstub(:request_configure)
    Dkim::ConfigureDkimRecord.any_instance.unstub(:add_dns_records_to_aws)
  end

  def test_dkim_configure_without_feature_failure
    @verified_email_config = create_email_config(support_email: 'test@fresh.com')
    make_email_config_active(@verified_email_config)
    Account.any_instance.stubs(:launched?).returns(false)
    @controller.stubs(:sendgrid_verified_domain?).returns(true)
    Dkim::ConfigureDkimRecord.any_instance.stubs(:make_api).returns(nil)
    Dkim::ConfigureDkimRecord.any_instance.stubs(:request_configure).returns({:record_1 => [500,{}], :record_2 => [500,{}]})
    Dkim::ConfigureDkimRecord.any_instance.stubs(:add_dns_records_to_aws).returns(nil)
    non_configured_domain = @account.outgoing_email_domain_categories.find_by_email_domain('fresh.com')
    change_domain_status(non_configured_domain, 0)
    post :create, {id: non_configured_domain.id}
    assert_response 200
    assert_equal true, response.body.include?('The domain is verified in another account')
    assert_equal 1, response.body.scan('Configure').count
    assert_equal 0, response.body.scan('Unverified').count
    assert_equal 0, response.body.scan('dkim-table-wraper').count
  ensure
    @verified_email_config.destroy
    Account.any_instance.unstub(:launched?)
    Dkim::ConfigureDkimRecord.any_instance.unstub(:sendgrid_verified_domain?)
    Dkim::ConfigureDkimRecord.any_instance.unstub(:make_api)
    Dkim::ConfigureDkimRecord.any_instance.unstub(:request_configure)
    Dkim::ConfigureDkimRecord.any_instance.unstub(:add_dns_records_to_aws)
  end
  
  def test_dkim_verify_with_feature
    @verified_email_config = create_email_config(support_email: 'test@fresh.com')
    make_email_config_active(@verified_email_config)
    Account.any_instance.stubs(:launched?).returns(true)
    HttpRequestProxy.any_instance.stubs(:fetch_using_req_params).returns(status: 200, text: email_service_verify_hash)
    non_configured_domain1 = @account.outgoing_email_domain_categories.find_by_email_domain('fresh.com')
    change_domain_status(non_configured_domain1, 0)
    post :create, {id: non_configured_domain1.id}
    assert_response 200
    get :verify_email_domain, {id: non_configured_domain1.id}
    assert_response 200
    non_configured_domain1.reload
    assert_equal true, response.body.include?('fresh.com')
    assert_equal 2, non_configured_domain1.status
    assert_equal 1, response.body.scan('dkim-table-wraper').count
  ensure
    @verified_email_config.destroy
    Account.any_instance.unstub(:launched?)
    HttpRequestProxy.any_instance.unstub(:fetch_using_req_params)
  end  
end
