require_relative '../test_helper'
require 'minitest/spec'

class MigrationHelperTest < ActiveSupport::TestCase
  def setup
    super
    @test_obj = Object.new
    @test_obj.extend(Freshid::Fdadmin::MigrationHelper)
    Account.stubs(:current).returns(Account.first)
  end

  def teardown
    Account.unstub(:current)
    super
  end

  def test_get_freshchat_preferred_domain
    assert_equal 'testaccount.freshpori.com', @test_obj.get_freshchat_preferred_domain('testaccount')
    assert_equal 'testaccount.freshpori.com', @test_obj.get_freshchat_preferred_domain('testaccount.freshpori.com')
  end

  def test_get_freshchat_preferred_domain_production
    Rails.env.stubs(:production?).returns(true)
    assert_equal 'testaccount.freshchat.com', @test_obj.get_freshchat_preferred_domain('testaccount')
    assert_equal 'testaccount.freshchat.com', @test_obj.get_freshchat_preferred_domain('testaccount.freshchat.com')
  ensure
    Rails.env.unstub(:production?)
  end

  def enable_freshid_sso_sync
    Account.any_instance.stubs(:freshid_org_v2_enabled?).returns(true)
    @test_obj.enable_freshid_sso_sync(Account.current)
    assert_equal true, Account.current.freshid_sso_sync_enabled?
  ensure
    Account.current.rollback(:freshid_sso_sync)
    Account.any_instance.unstub(:freshid_org_v2_enabled?).returns(true)
  end
end
