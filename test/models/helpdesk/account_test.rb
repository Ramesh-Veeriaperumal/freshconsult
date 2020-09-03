require_relative '../test_helper'
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')

class AccountTest < ActiveSupport::TestCase
  include AccountTestHelper

  def setup
    create_test_account if @account.nil?
  end

  def test_account_find_with_valid_account_id
    Rails.logger.debug "Account helper inspection #{@account.inspect}"
    assert_equal Account.find(@account.id), @account
  end

  def test_account_not_found_custom_error_for_invalid_account_id
    invalid_id = Account.maximum(:id) + 100
    assert_raises Account::RecordNotFound do
      Account.find(invalid_id)
    end
  end

  def test_enable_secure_attachments
    @account.revoke_feature(:private_inline)
    @account.add_feature(:secure_attachments)
    assert @account.private_inline_enabled?
  ensure
    @account.revoke_feature(:secure_attachments)
  end

  def test_disable_secure_attachments
    @account.add_feature(:secure_attachments)
    @account.add_feature(:private_inline)
    @account.revoke_feature(:secure_attachments)
    assert_equal @account.private_inline_enabled?, false
  ensure
    @account.revoke_feature(:private_inline)
  end

  def test_enable_setting_with_launch_party
    launch_party = Account::LP_FEATURES.last
    is_lp_enabled = @account.send("#{launch_party}_enabled?")
    @account.rollback(launch_party)
    assert_equal @account.send("#{launch_party}_enabled?"), false
    @account.enable_setting(launch_party)
    assert @account.send("#{launch_party}_enabled?")
  ensure
    is_lp_enabled ? @account.launch(launch_party) : @account.rollback(launch_party)
  end

  def test_disable_setting_with_launch_party
    launch_party = Account::LP_FEATURES.last
    is_lp_enabled = @account.send("#{launch_party}_enabled?")
    @account.enable_setting(launch_party)
    @account.disable_setting(launch_party)
    assert_equal @account.send("#{launch_party}_enabled?"), false
  ensure
    is_lp_enabled ? @account.launch(launch_party) : @account.rollback(launch_party)
  end

  def test_enable_setting_with_feature
    feature = Account::BITMAP_FEATURES.last
    is_feature_enabled = @account.send("#{feature}_enabled?")
    @account.revoke_feature(feature)
    assert_equal @account.send("#{feature}_enabled?"), false
    @account.enable_setting(feature)
    assert @account.send("#{feature}_enabled?")
  ensure
    is_feature_enabled ? @account.add_feature(feature) : @account.revoke_feature(feature)
  end

  def test_disable_setting_with_feature
    feature = Account::BITMAP_FEATURES.last
    is_feature_enabled = @account.send("#{feature}_enabled?")
    @account.enable_setting(feature)
    @account.disable_setting(feature)
    assert_equal @account.send("#{feature}_enabled?"), false
  ensure
    is_feature_enabled ? @account.add_feature(feature) : @account.revoke_feature(feature)
  end

  def test_disable_setting_with_invalid_value_doesnt_raise_error
    @account.disable_setting(:abcd)
  end
end
