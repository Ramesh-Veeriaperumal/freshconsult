# frozen_string_literal: true

require_relative '../../api/unit_test_helper'
['dkim_test_helper.rb'].each { |file| require Rails.root.join("test/lib/helpers/#{file}") }
require_relative '../../api/helpers/email_mailbox_test_helper.rb'

class RemoveDkimTest < ActionView::TestCase
  include EmailMailboxTestHelper
  include DkimTestHelper

  def setup
    super
    Account.stubs(:current).returns(Account.first)
    @test_email_config = create_email_config(support_email: 'test@dkimtest.com')
    @domain = Account.current.outgoing_email_domain_categories.find_by_email_domain('dkimtest.com')
    @domain.category = 31
    @domain.status = 3
    @domain.save!
    update_email_config_category(@test_email_config, 31)
    @domain.dkim_records.new(sg_data).save!
  end

  def teardown
    Account.unstub(:current)
    @test_email_config.destroy
    @domain.dkim_records.destroy_all if @domain.dkim_records.present?
    @domain.destroy
    super
  end

  def test_remove_with_email_service_records_for_fdm_selector
    HttpRequestProxy.any_instance.stubs(:fetch_using_req_params).returns(status: 200, text: email_service_fetch_domain_hash_fdm)
    Dkim::RemoveDkim.any_instance.stubs(:handle_dns_action).returns(true)
    Dkim::RemoveDkim.any_instance.stubs(:new_record?).returns(false)
    Dkim::EmailServiceHttp.any_instance.stubs(:remove_domain).returns(status: 204)
    Dkim::RemoveDkim.new(@domain).remove
    @domain.reload
    @test_email_config.reload
    assert_equal @domain.status, 0
    assert_nil @domain.category
    assert_nil @test_email_config.category
  ensure
    Dkim::EmailServiceHttp.any_instance.unstub(:fetch_domain)
    Dkim::RemoveDkim.any_instance.unstub(:handle_dns_action)
    Dkim::EmailServiceHttp.any_instance.unstub(:remove_domain)
    Dkim::RemoveDkim.any_instance.unstub(:new_record?)
  end

  def test_remove_with_email_service_records_for_m1_selector
    HttpRequestProxy.any_instance.stubs(:fetch_using_req_params).returns(status: 200, text: email_service_fetch_domain_hash_m1)
    Dkim::RemoveDkim.any_instance.stubs(:handle_dns_action).returns(true)
    Dkim::RemoveDkim.any_instance.stubs(:new_record?).returns(false)
    Dkim::EmailServiceHttp.any_instance.stubs(:remove_domain).returns(status: 204)
    Dkim::RemoveDkim.new(@domain).remove
    @domain.reload
    @test_email_config.reload
    assert_equal @domain.status, 0
    assert_nil @domain.category
    assert_nil @test_email_config.category
  ensure
    Dkim::EmailServiceHttp.any_instance.unstub(:fetch_domain)
    Dkim::RemoveDkim.any_instance.unstub(:handle_dns_action)
    Dkim::EmailServiceHttp.any_instance.unstub(:remove_domain)
    Dkim::RemoveDkim.any_instance.unstub(:new_record?)
  end

  def test_remove_without_email_service_records
    Dkim::EmailServiceHttp.any_instance.stubs(:fetch_domain).returns(email_service_fetch_domain_failure)
    Dkim::RemoveDkim.any_instance.stubs(:handle_dns_action).returns(true)
    HttpRequestProxy.any_instance.stubs(:fetch_using_req_params).returns(status: 'Failure')
    Dkim::RemoveDkim.any_instance.stubs(:new_record?).returns(false)
    Dkim::RemoveDkim.new(@domain).remove
    @domain.reload
    @test_email_config.reload
    assert_equal @domain.status, 0
    assert_nil @domain.category
    assert_nil @test_email_config.category
  ensure
    Dkim::EmailServiceHttp.any_instance.unstub(:fetch_domain)
    Dkim::RemoveDkim.any_instance.unstub(:handle_dns_action)
    HttpRequestProxy.any_instance.unstub(:fetch_using_req_params)
    Dkim::RemoveDkim.any_instance.unstub(:new_record?)
  end

  def test_remove_failure_when_es_fails
    Dkim::EmailServiceHttp.any_instance.stubs(:fetch_domain).returns(status: 200, text: email_service_fetch_domain_hash_fdm)
    Dkim::RemoveDkim.any_instance.stubs(:handle_dns_action).returns(true)
    HttpRequestProxy.any_instance.stubs(:fetch_using_req_params).returns(status: 'Failure')
    Dkim::RemoveDkim.any_instance.stubs(:new_record?).returns(false)
    Dkim::RemoveDkim.new(@domain).remove
    @domain.reload
    @test_email_config.reload
    assert_equal @domain.status, 3
    assert_equal @domain.category, 31
    assert_equal @test_email_config.category, 31
  ensure
    Dkim::EmailServiceHttp.any_instance.unstub(:fetch_domain)
    Dkim::RemoveDkim.any_instance.unstub(:handle_dns_action)
    Dkim::EmailServiceHttp.any_instance.unstub(:remove_domain)
    Dkim::RemoveDkim.any_instance.unstub(:new_record?)
  end
end
