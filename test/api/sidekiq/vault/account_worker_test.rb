require_relative '../../unit_test_helper'
require 'sidekiq/testing'
require 'webmock/minitest'
WebMock.allow_net_connect!
Sidekiq::Testing.fake!
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
require Rails.root.join('test', 'api', 'helpers', 'ticket_fields_test_helper.rb')
class Vault::AccountWorkerTest < ActionView::TestCase
  include AccountTestHelper
  include TicketFieldsTestHelper

  def setup
    Account.stubs(:current).returns(Account.first)
    @account = Account.current
  end

  def test_register_account_vault_service_success_test
    Account.current.stubs(:secure_fields_toggle_enabled?).returns(true)
    @account.disable_setting(:secure_fields)
    @account.features.whitelisted_ips.create
    Account.any_instance.stubs(:whitelisted_ip).returns(whitelisted_ip_stub)
    stub_request(:put, PciConstants::ACCOUNT_INFO_URL).to_return(status: 204)
    Vault::AccountWorker.new.perform(action: PciConstants::ACCOUNT_UPDATE)
    @account.reload
    assert_equal true, @account.secure_fields_enabled?
  ensure
    Account.unstub(:current)
    @account.features.whitelisted_ips.destroy
    @account.disable_setting(:secure_fields)
    Account.current.unstub(:secure_fields_toggle_enabled?)
    Account.any_instance.unstub(:whitelisted_ip)
  end

  def test_register_account_vault_service_failure_test_when_ip_whitelisting_not_enabled
    Account.current.stubs(:secure_fields_toggle_enabled?).returns(true)
    @account.disable_setting(:secure_fields)
    stub_request(:put, PciConstants::ACCOUNT_INFO_URL).to_return(status: 204)
    Vault::AccountWorker.new.perform(action: PciConstants::ACCOUNT_UPDATE)
    @account.reload
    assert_equal false, @account.secure_fields_enabled?
  ensure
    Account.unstub(:current)
    @account.disable_setting(:secure_fields)
    Account.current.unstub(:secure_fields_toggle_enabled?)
  end

  def test_register_account_vault_service_failed_test
    Account.current.stubs(:secure_fields_toggle_enabled?).returns(true)
    @account.disable_setting(:secure_fields)
    stub_request(:put, PciConstants::ACCOUNT_INFO_URL).to_return(status: 403)
    Vault::AccountWorker.new.perform(action: PciConstants::ACCOUNT_UPDATE)
    @account.reload
    assert_equal false, @account.secure_fields_enabled?
  ensure
    Account.unstub(:current)
    @account.disable_setting(:secure_fields)
    Account.current.unstub(:secure_fields_toggle_enabled?)
  end

  def test_offboard_account_vault_service_success_test
    Account.current.stubs(:secure_fields_toggle_enabled?).returns(true)
    @account.enable_setting(:secure_fields)
    name = "secure_text_#{Faker::Lorem.characters(rand(10..20))}"
    create_custom_field_dn(name, 'secure_text')
    stub_request(:delete, PciConstants::ACCOUNT_INFO_URL).to_return(status: 204)
    Vault::AccountWorker.new.perform(action: PciConstants::ACCOUNT_ROLLBACK)
    @account.reload
    assert_equal false, @account.secure_fields_enabled?
    assert_equal @account.ticket_fields.where(field_type: TicketFieldsConstants::SECURE_TEXT).count, 0
  ensure
    Account.unstub(:current)
    @account.disable_setting(:secure_fields)
    Account.current.unstub(:secure_fields_toggle_enabled?)
  end

  def test_offboard_account_vault_service_failure_test
    Account.current.stubs(:secure_fields_toggle_enabled?).returns(true)
    @account.enable_setting(:secure_fields)
    stub_request(:delete, PciConstants::ACCOUNT_INFO_URL).to_return(status: 403)
    Vault::AccountWorker.new.perform(action: PciConstants::ACCOUNT_ROLLBACK)
    @account.reload
    assert_equal false, @account.secure_fields_enabled?
  ensure
    Account.unstub(:current)
    @account.disable_setting(:secure_fields)
    Account.current.unstub(:secure_fields_toggle_enabled?)
  end

  def test_idle_session_time_out_and_single_session_per_user_when_account_vault_service_success
    Account.current.stubs(:secure_fields_toggle_enabled?).returns(true)
    @account.enable_setting(:secure_fields)
    @account.features.whitelisted_ips.create
    Account.any_instance.stubs(:whitelisted_ip).returns(whitelisted_ip_stub)
    stub_request(:put, PciConstants::ACCOUNT_INFO_URL).to_return(status: 204)
    Vault::AccountWorker.new.perform(action: PciConstants::ACCOUNT_UPDATE, enable_pci_compliance: true)
    @account.reload
    assert_equal true, @account.secure_fields_enabled?, 'secure_fields not enabled'
    assert_equal true, @account.idle_session_timeout_enabled?, 'idle_session_timeout not enabled'
    assert_equal true, @account.has_feature?(:single_session_per_user), 'single_session_per_user not enabled'
  ensure
    Account.unstub(:current)
    @account.features.whitelisted_ips.destroy
    @account.disable_setting(:secure_fields)
    Account.current.unstub(:secure_fields_toggle_enabled?)
    @account.revoke_feature(:idle_session_timeout)
    @account.revoke_feature(:single_session_per_user)
    Account.any_instance.unstub(:whitelisted_ip)
  end

  private

    def whitelisted_ip_stub
      WhitelistedIp.new(
        enabled: true,
        ip_ranges: [{ start_ip: '127.0.0.1' }],
        applies_only_to_agents: true
      )
    end
end
