# frozen_string_literal: true

require_relative '../../unit_test_helper'
require_relative '../../test_helper'
require 'webmock/minitest'
require 'sidekiq/testing'
WebMock.allow_net_connect!
require Rails.root.join('test', 'models', 'helpers', 'freshchat_account_test_helper.rb')
require Rails.root.join('test', 'models', 'helpers', 'freshcaller_account_test_helper.rb')
['account_test_helper.rb', 'aloha_signup_test_helper.rb'].each { |file| require "#{Rails.root}/test/core/helpers/#{file}" }
Sidekiq::Testing.fake!

class OmniChannelDashboard::AccountWorkerTest < ActionView::TestCase
  include FreshcallerAccountTestHelper
  include FreshchatAccountTestHelper
  include AlohaSignupTestHelper
  include OmniChannelDashboard::Constants

  def setup
    @account = Account.first || create_test_account
    @account.make_current
    if @account.organisation.blank?
      @org = create_organisation(1234, @account.domain)
      create_organisation_account_mapping(@org.id)
    end
    @fchat_acc = create_freshchat_account @account unless @account.freshchat_account
    @fcaller_acc = create_freshcaller_account @account unless @account.freshcaller_account
  end

  def test_launch_omni_channel_dashboard_success_test_account_update
    @account.rollback(:omni_channel_dashboard)
    @account.launch(:omni_bundle_2020)
    Account.any_instance.stubs(:omni_bundle_id).returns(123)
    stub_request(:put, @account.full_domain + ACCOUNT_UPDATE_API_PATH + @account.id.to_s).to_return(status: 204)
    OmniChannelDashboard::AccountWorker.new.perform(action: 'update')
    @account.reload
    assert_equal true, @account.omni_channel_dashboard_enabled?
  ensure
    @fchat_acc.destroy if @fchat_acc
    @fcaller_acc.destroy if @fcaller_acc
    OrganisationAccountMapping.find(@org.id).destroy if @org
    @account.rollback(:omni_channel_dashboard)
    @account.rollback(:omni_bundle_2020)
    Account.reset_current_account
  end

  def test_launch_omni_channel_dashboard_success_test_account_create
    @account.rollback(:omni_channel_dashboard)
    @account.launch(:omni_bundle_2020)
    Account.any_instance.stubs(:omni_bundle_id).returns(123)
    stub_request(:post, @account.full_domain + ACCOUNT_CREATE_API_PATH).to_return(status: 204)
    OmniChannelDashboard::AccountWorker.new.perform(action: 'create')
    @account.reload
    assert_equal true, @account.omni_channel_dashboard_enabled?
  ensure
    @fchat_acc.destroy if @fchat_acc
    @fcaller_acc.destroy if @fcaller_acc
    OrganisationAccountMapping.find(@org.id).destroy if @org
    @account.rollback(:omni_channel_dashboard)
    @account.rollback(:omni_bundle_2020)
    Account.reset_current_account
  end

  def test_worker_when_omni_bundle_feature_is_not_present
    @account.rollback(:omni_channel_dashboard)
    @account.rollback(:omni_bundle_2020)
    @account.stubs(:omni_bundle_account?).returns(false)
    stub_request(:put, @account.full_domain + ACCOUNT_UPDATE_API_PATH + @account.id.to_s).to_return(status: 204)
    OmniChannelDashboard::AccountWorker.new.perform(action: 'update')
    @account.reload
    assert_equal false, @account.omni_channel_dashboard_enabled?
  ensure
    @fchat_acc.destroy if @fchat_acc
    @fcaller_acc.destroy if @fcaller_acc
    OrganisationAccountMapping.find(@org.id).destroy if @org
    @account.rollback(:omni_channel_dashboard)
    @account.rollback(:omni_bundle_2020)
    Account.reset_current_account
  end

  def test_launch_omni_channel_dashboard_failed_test
    @account.rollback(:omni_channel_dashboard)
    @account.stubs(:omni_bundle_2020).returns(true)
    Account.any_instance.stubs(:omni_bundle_id).returns(123)
    OmniChannelDashboard::AccountWorker.new.perform(action: 'update')
    @account.reload
    assert_equal false, @account.omni_channel_dashboard_enabled?
  ensure
    @fchat_acc.destroy if @fchat_acc
    @fcaller_acc.destroy if @fcaller_acc
    OrganisationAccountMapping.find(@org.id).destroy if @org
    @account.rollback(:omni_channel_dashboard)
    @account.rollback(:omni_bundle_2020)
    Account.reset_current_account
  end

  def test_launch_omni_channel_dashboard_failed_test_with_invalid_action
    @account.rollback(:omni_channel_dashboard)
    @account.stubs(:omni_bundle_2020).returns(true)
    Account.any_instance.stubs(:omni_bundle_id).returns(123)
    stub_request(:put, @account.full_domain + ACCOUNT_UPDATE_API_PATH + @account.id.to_s).to_return(status: 204)
    OmniChannelDashboard::AccountWorker.new.perform(action: 'sample')
    @account.reload
    assert_equal false, @account.omni_channel_dashboard_enabled?
  ensure
    @fchat_acc.destroy if @fchat_acc
    @fcaller_acc.destroy if @fcaller_acc
    OrganisationAccountMapping.find(@org.id).destroy if @org
    @account.rollback(:omni_channel_dashboard)
    @account.rollback(:omni_bundle_2020)
    Account.reset_current_account
  end
end
