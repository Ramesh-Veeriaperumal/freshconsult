require_relative '../test_helper'
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')

class Account::SettingsTest < ActiveSupport::TestCase
  include AccountTestHelper

  def setup
    create_test_account if @account.nil?
  end

  def test_enable_setting_with_dependent_feature
    # setup
    setting = AccountSettings::SettingsConfig.keys.sample.to_sym
    required_feature = AccountSettings::SettingsConfig[setting][:feature_dependency]

    is_setting_enabled = @account.has_feature?(setting)
    @account.revoke_feature(setting)
    assert_equal @account.has_feature?(setting), false
  
    is_required_feature_enabled = @account.has_feature?(required_feature)
    @account.add_feature(required_feature)
    assert @account.has_feature?(required_feature)
    # when
    @account.enable_setting(setting)
    # then
    assert @account.send("#{setting}_enabled?")
  ensure
    is_setting_enabled ? @account.add_feature(setting) : @account.revoke_feature(setting)
    is_required_feature_enabled ? @account.add_feature(required_feature) : @account.revoke_feature(required_feature)
  end

  def test_enable_setting_without_dependent_feature
    # setup
    setting = AccountSettings::SettingsConfig.keys.sample.to_sym
    required_feature = AccountSettings::SettingsConfig[setting][:feature_dependency]

    is_setting_enabled = @account.has_feature?(setting)
    @account.revoke_feature(setting)
    assert_equal @account.has_feature?(setting), false

    is_required_feature_enabled = @account.has_feature?(required_feature)
    @account.revoke_feature(required_feature)
    assert_equal @account.has_feature?(required_feature), false
    # when + then
    assert_raise RuntimeError do
      @account.enable_setting(setting)
      assert @account.has_feature?(setting), false
    end    
  ensure
    is_setting_enabled ? @account.add_feature(setting) : @account.revoke_feature(setting)
    is_required_feature_enabled ? @account.add_feature(required_feature) : @account.revoke_feature(required_feature)
  end

  def test_disable_setting_with_dependent_feature
    # setup
    setting = AccountSettings::SettingsConfig.keys.sample.to_sym
    required_feature = AccountSettings::SettingsConfig[setting][:feature_dependency]

    is_setting_enabled = @account.has_feature?(setting)
    @account.add_feature(setting)
    assert @account.has_feature?(setting)
  
    is_required_feature_enabled = @account.has_feature?(required_feature)
    @account.add_feature(required_feature)
    assert @account.has_feature?(required_feature)
    # when
    @account.disable_setting(setting)
    # then
    assert_equal @account.send("#{setting}_enabled?"), false
  ensure
    is_setting_enabled ? @account.add_feature(setting) : @account.revoke_feature(setting)
    is_required_feature_enabled ? @account.add_feature(required_feature) : @account.revoke_feature(required_feature)
  end

  def test_disable_setting_without_dependent_feature
    # setup
    setting = AccountSettings::SettingsConfig.keys.sample.to_sym
    required_feature = AccountSettings::SettingsConfig[setting][:feature_dependency]

    is_setting_enabled = @account.has_feature?(setting)
    @account.add_feature(setting)
    assert @account.has_feature?(setting)
  
    is_required_feature_enabled = @account.has_feature?(required_feature)
    @account.revoke_feature(required_feature)
    assert_equal @account.has_feature?(required_feature), false
    # when + then
    assert_raise RuntimeError do
      @account.disable_setting(setting)
      assert @account.has_feature?(setting)
    end  
  ensure
    is_setting_enabled ? @account.add_feature(setting) : @account.revoke_feature(setting)
    is_required_feature_enabled ? @account.add_feature(required_feature) : @account.revoke_feature(required_feature)
  end

  # def test_disable_setting_with_feature
  #   feature = Account::BITMAP_FEATURES.last
  #   is_feature_enabled = @account.send("#{feature}_enabled?")
  #   @account.enable_setting(feature)
  #   @account.disable_setting(feature)
  #   assert_equal @account.send("#{feature}_enabled?"), false
  # ensure
  #   is_feature_enabled ? @account.add_feature(feature) : @account.revoke_feature(feature)
  # end

  def test_disable_setting_with_invalid_value_doesnt_raise_error
    @account.disable_setting(:abcd)
  end


  def test_enable_setting_with_invalid_value_doesnt_raise_error
    @account.enable_setting(:abcd)
  end
end
