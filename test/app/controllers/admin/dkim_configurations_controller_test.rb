require_relative '../../../api/test_helper'
['dkim_test_helper.rb'].each { |file| require Rails.root.join("test/lib/helpers/#{file}") }
class Admin::DkimConfigurationsControllerTest < ActionController::TestCase
  include EmailMailboxTestHelper
  include DkimTestHelper
  include Redis::OthersRedis
  include Redis::Keys::Others

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
    Account.any_instance.stubs(:dkim_email_service_enabled?).returns(true)
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
    Account.any_instance.unstub(:dkim_email_service_enabled?)
    HttpRequestProxy.any_instance.unstub(:fetch_using_req_params)
  end

  def test_dkim_configurations_index_without_feature
    @verified_email_config = create_email_config(support_email: 'test@fresh.com')
    make_email_config_active(@verified_email_config)
    @verified_email_config2 = create_email_config(support_email: 'test2@fresh2.com')
    make_email_config_active(@verified_email_config2)
    Account.any_instance.stubs(:dkim_email_service_enabled?).returns(false)
    get :index
    assert_response 200
    assert_equal true, response.body.include?('fresh.com')
    assert_equal true, response.body.include?('fresh2.com')
    assert_equal 2, response.body.scan('Configure').count
  ensure
    @verified_email_config.destroy
    @verified_email_config2.destroy
    Account.any_instance.unstub(:dkim_email_service_enabled?)
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
    Account.any_instance.stubs(:dkim_email_service_enabled?).returns(true)
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
    Account.any_instance.unstub(:dkim_email_service_enabled?)
    HttpRequestProxy.any_instance.unstub(:fetch_using_req_params)
  end

  def test_dkim_configure_with_feature
    @verified_email_config = create_email_config(support_email: 'test@fresh.com')
    make_email_config_active(@verified_email_config)
    Account.any_instance.stubs(:dkim_email_service_enabled?).returns(true)
    HttpRequestProxy.any_instance.stubs(:fetch_using_req_params).returns(status: 200, text: email_service_configure_hash)
    non_configured_domain1 = @account.outgoing_email_domain_categories.find_by_email_domain('fresh.com')
    change_domain_status(non_configured_domain1, 0)
    post :create, id: non_configured_domain1.id
    assert_response 200
    assert_equal true, response.body.include?('fresh.com')
    assert_equal 1, response.body.scan('Unverified').count
    assert_equal 1, response.body.scan('dkim-table-wraper').count
  ensure
    @verified_email_config.destroy
    Account.any_instance.unstub(:dkim_email_service_enabled?)
    HttpRequestProxy.any_instance.unstub(:fetch_using_req_params)
  end

  def test_dkim_configure_with_error_response
    @verified_email_config = create_email_config(support_email: 'test@fresh.com')
    make_email_config_active(@verified_email_config)
    Account.any_instance.stubs(:dkim_email_service_enabled?).returns(true)
    HttpRequestProxy.any_instance.stubs(:fetch_using_req_params).returns(status: 500, text: email_service_failure_hash)
    non_configured_domain = @account.outgoing_email_domain_categories.find_by_email_domain('fresh.com')
    change_domain_status(non_configured_domain, 0)
    post :create, id: non_configured_domain.id
    assert_response 200
    assert_equal true, response.body.include?('Cannot configure DKIM settings. Please try again later')
    assert_equal 1, response.body.scan('Configure').count
    assert_equal 0, response.body.scan('Unverified').count
    assert_equal 0, response.body.scan('dkim-table-wraper').count
  ensure
    @verified_email_config.destroy
    Account.any_instance.unstub(:dkim_email_service_enabled?)
    HttpRequestProxy.any_instance.unstub(:fetch_using_req_params)
  end

  def test_dkim_configure_without_feature
    @verified_email_config = create_email_config(support_email: 'test@fresh.com')
    make_email_config_active(@verified_email_config)
    Account.any_instance.stubs(:dkim_email_service_enabled?).returns(false)
    Dkim::ConfigureDkimRecord.any_instance.stubs(:sendgrid_verified_domain?).returns(false)
    Dkim::ConfigureDkimRecord.any_instance.stubs(:make_api).returns(record_1: sg_response_1, record_2: sg_response_2)
    Dkim::ConfigureDkimRecord.any_instance.stubs(:request_configure).returns(record_1: sg_response_1, record_2: sg_response_2)
    Dkim::ConfigureDkimRecord.any_instance.stubs(:add_dns_records_to_aws).returns(nil)
    non_configured_domain = @account.outgoing_email_domain_categories.find_by_email_domain('fresh.com')
    change_domain_status(non_configured_domain, 0)
    post :create, id: non_configured_domain.id
    assert_response 200
    assert_equal true, response.body.include?('fresh.com')
    assert_equal 1, response.body.scan('Unverified').count
    assert_equal 1, response.body.scan('dkim-table-wraper').count
  ensure
    @verified_email_config.destroy
    Account.any_instance.unstub(:dkim_email_service_enabled?)
    Dkim::ConfigureDkimRecord.any_instance.unstub(:sendgrid_verified_domain?)
    Dkim::ConfigureDkimRecord.any_instance.unstub(:make_api)
    Dkim::ConfigureDkimRecord.any_instance.unstub(:request_configure)
    Dkim::ConfigureDkimRecord.any_instance.unstub(:add_dns_records_to_aws)
  end

  def test_dkim_configure_without_feature_failure
    @verified_email_config = create_email_config(support_email: 'test@fresh.com')
    make_email_config_active(@verified_email_config)
    Account.any_instance.stubs(:dkim_email_service_enabled?).returns(false)
    @controller.stubs(:sendgrid_verified_domain?).returns(true)
    Dkim::ConfigureDkimRecord.any_instance.stubs(:make_api).returns(nil)
    Dkim::ConfigureDkimRecord.any_instance.stubs(:request_configure).returns(record_1: [500, {}], record_2: [500, {}])
    Dkim::ConfigureDkimRecord.any_instance.stubs(:add_dns_records_to_aws).returns(nil)
    non_configured_domain = @account.outgoing_email_domain_categories.find_by_email_domain('fresh.com')
    change_domain_status(non_configured_domain, 0)
    post :create, id: non_configured_domain.id
    assert_response 200
    assert_equal true, response.body.include?('The domain is verified in another account')
    assert_equal 1, response.body.scan('Configure').count
    assert_equal 0, response.body.scan('Unverified').count
    assert_equal 0, response.body.scan('dkim-table-wraper').count
  ensure
    @verified_email_config.destroy
    Account.any_instance.unstub(:dkim_email_service_enabled?)
    Dkim::ConfigureDkimRecord.any_instance.unstub(:sendgrid_verified_domain?)
    Dkim::ConfigureDkimRecord.any_instance.unstub(:make_api)
    Dkim::ConfigureDkimRecord.any_instance.unstub(:request_configure)
    Dkim::ConfigureDkimRecord.any_instance.unstub(:add_dns_records_to_aws)
  end

  def test_dkim_remove
    @verified_email_config = create_email_config(support_email: 'test@fresh7.com')
    make_email_config_active(@verified_email_config)
    non_configured_domain1 = @account.outgoing_email_domain_categories.find_by_email_domain('fresh7.com')
    change_domain_status(non_configured_domain1, 2)

    Account.any_instance.stubs(:dkim_email_service_enabled?).returns(true)
    HttpRequestProxy.any_instance.stubs(:fetch_using_req_params).returns(status: 204, text: {}.to_json)

    post :remove_dkim_config, id: non_configured_domain1.id
    assert_response 302
  ensure
    @verified_email_config.destroy
    Account.any_instance.unstub(:dkim_email_service_enabled?)
    HttpRequestProxy.any_instance.unstub(:fetch_using_req_params)
  end

  def test_dkim_remove_for_migrated_sendgrid_accounts
    @verified_email_config = create_email_config(support_email: 'test@fresh8.com')
    make_email_config_active(@verified_email_config)
    non_configured_domain1 = @account.outgoing_email_domain_categories.find_by_email_domain('fresh8.com')
    change_domain_status(non_configured_domain1, 2)

    Account.any_instance.stubs(:dkim_email_service_enabled?).returns(true)
    HttpRequestProxy.any_instance.stubs(:fetch_using_req_params).returns(status: 204, text: {}.to_json)
    Dkim::RemoveDkim.any_instance.stubs(:last_email_domain?).returns(true)
    Dkim::RemoveDkim.any_instance.stubs(:handle_dns_action).returns(true)
    post :remove_dkim_config, id: non_configured_domain1.id
    assert_response 302
    non_configured_domain1.reload
    assert_equal 3, non_configured_domain1.status
  ensure
    @verified_email_config.destroy
    Account.any_instance.unstub(:dkim_email_service_enabled?)
    HttpRequestProxy.any_instance.unstub(:fetch_using_req_params)
    Dkim::RemoveDkim.any_instance.unstub(:last_email_domain?)
    Dkim::RemoveDkim.any_instance.unstub(:handle_dns_action)
  end

  def test_dkim_index_for_manually_configured_domains
    @verified_email_config = create_email_config(support_email: 'test@fresh.com')
    make_email_config_active(@verified_email_config)
    active_domain = @account.outgoing_email_domain_categories.find_by_email_domain('fresh.com')
    change_domain_status(active_domain, 2)
    @verified_email_config2 = create_email_config(support_email: 'test2@fresh2.com')
    make_email_config_active(@verified_email_config2)
    manually_configured_domain = @account.outgoing_email_domain_categories.find_by_email_domain('fresh2.com')
    change_domain_status(manually_configured_domain, 2)
    manually_configured_domain.category = 5
    manually_configured_domain.save!
    Account.any_instance.stubs(:dkim_email_service_enabled?).returns(true)
    HttpRequestProxy.any_instance.stubs(:fetch_using_req_params).returns(status: 200, text: email_service_response_hash)
    add_member_to_redis_set(
      format(
        MIGRATE_MANUALLY_CONFIGURED_DOMAINS,
        account_id: Account.current.id
      ),
      'fresh.com'
    )
    get :index
    assert_response 200
    assert_equal true, response.body.include?('fresh.com')
    assert_equal true, response.body.include?('fresh2.com')
    assert_equal 1, response.body.scan('Configure').count
    assert_equal 0, response.body.scan('Unverified').count
  ensure
    @verified_email_config.destroy
    @verified_email_config2.destroy
    Account.any_instance.unstub(:dkim_email_service_enabled?)
    HttpRequestProxy.any_instance.unstub(:fetch_using_req_params)
    remove_member_from_redis_set(
      format(
        MIGRATE_MANUALLY_CONFIGURED_DOMAINS,
        account_id: Account.current.id
      ),
      'fresh.com'
    )
  end

  def test_dkim_configure_for_manually_configured_domains
    @verified_email_config = create_email_config(support_email: 'test2@fresh.com')
    make_email_config_active(@verified_email_config)
    manually_configured_domain = @account.outgoing_email_domain_categories.find_by_email_domain('fresh.com')
    change_domain_status(manually_configured_domain, 2)
    manually_configured_domain.category = 5
    manually_configured_domain.save!
    add_member_to_redis_set(
      format(
        MIGRATE_MANUALLY_CONFIGURED_DOMAINS,
        account_id: Account.current.id
      ),
      'fresh.com'
    )
    Account.any_instance.stubs(:dkim_email_service_enabled?).returns(true)
    HttpRequestProxy.any_instance.stubs(:fetch_using_req_params).returns(status: 200, text: email_service_configure_hash)
    post :create, id: manually_configured_domain.id
    assert_response 200
    assert_equal true, response.body.include?('fresh.com')
    assert_equal 0, response.body.scan('Configure').count
    assert_equal 1, response.body.scan('Unverified').count
    assert_equal false, ismember?(
      format(
        MIGRATE_MANUALLY_CONFIGURED_DOMAINS,
        account_id: Account.current.id
      ),
      'fresh.com'
    )
    manually_configured_domain.reload
    assert_equal 1, manually_configured_domain.status
  ensure
    @verified_email_config.destroy
    Account.any_instance.unstub(:dkim_email_service_enabled?)
    HttpRequestProxy.any_instance.unstub(:fetch_using_req_params)
  end
end
