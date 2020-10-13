# frozen_string_literal: true

require_relative '../test_helper'
require Rails.root.join('spec', 'support', 'account_helper.rb')

class Account::SettingsTest < ActiveSupport::TestCase
  include AccountHelper

  def setup
    @account = Account.first
    create_test_account if @account.nil?
    Account.stubs(:current).returns(@account)
  end

  def test_type_of_setting_with_dependent_feature
    setting = AccountSettings::SettingsConfig.keys.sample.to_sym
    setting_hash = AccountSettings::SettingsConfig[setting]
    internal_setting = setting_hash[:internal]
    required_feature = setting_hash[:feature_dependency]
    is_required_feature_enabled = @account.has_feature?(required_feature)
    @account.add_feature(required_feature)
    assert @account.has_feature?(required_feature)
    assert_equal @account.internal_setting_for_account?(setting), internal_setting
    assert_equal @account.admin_setting_for_account?(setting), !internal_setting
  ensure
    is_required_feature_enabled ? @account.add_feature(required_feature) : @account.revoke_feature(required_feature)
  end

  def test_type_of_setting_without_dependent_feature
    setting = AccountSettings::SettingsConfig.keys.sample.to_sym
    required_feature = AccountSettings::SettingsConfig[setting][:feature_dependency]
    is_required_feature_enabled = @account.has_feature?(required_feature)
    @account.revoke_feature(required_feature)
    assert_equal @account.has_feature?(required_feature), false
    assert_equal @account.internal_setting_for_account?(setting), false
    assert_equal @account.admin_setting_for_account?(setting), false
  ensure
    is_required_feature_enabled ? @account.add_feature(required_feature) : @account.revoke_feature(required_feature)
  end

  def test_type_of_setting_for_invalid_setting
    assert_equal @account.internal_setting_for_account?(:abc), nil
    assert_equal @account.admin_setting_for_account?(:abc), nil
  end

  def test_enable_setting_with_dependent_feature
    # setup
    # except :compose_email as the method is overridden
    setting = AccountSettings::SettingsConfig.except('compose_email').keys.sample.to_sym
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
    # except :compose_email as the method is overridden
    setting = AccountSettings::SettingsConfig.except('compose_email').keys.sample.to_sym
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

  def test_set_setting_with_dependent_feature
    # setup
    # except :compose_email as the method is overridden
    setting = AccountSettings::SettingsConfig.except('compose_email').keys.sample.to_sym
    required_feature = AccountSettings::SettingsConfig[setting][:feature_dependency]
    is_setting_enabled = @account.has_feature?(setting)
    @account.revoke_feature(setting)
    assert_equal @account.has_feature?(setting), false
    is_required_feature_enabled = @account.has_feature?(required_feature)
    @account.add_feature(required_feature)
    assert @account.has_feature?(required_feature)
    # when
    @account.set_setting(setting)
    # then
    assert @account.changes.key?('plan_features')
    assert @account.send("#{setting}_enabled?")
    assert_equal Account.find(@account.id).send("#{setting}_enabled?"), false
  ensure
    @account.reset_plan_features!
    is_setting_enabled ? @account.add_feature(setting) : @account.revoke_feature(setting)
    is_required_feature_enabled ? @account.add_feature(required_feature) : @account.revoke_feature(required_feature)
  end

  def test_set_setting_without_dependent_feature
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
      @account.set_setting(setting)
      assert @account.has_feature?(setting), false
    end
  ensure
    is_setting_enabled ? @account.add_feature(setting) : @account.revoke_feature(setting)
    is_required_feature_enabled ? @account.add_feature(required_feature) : @account.revoke_feature(required_feature)
  end

  def test_reset_setting_with_dependent_feature
    # setup
    setting = AccountSettings::SettingsConfig.except('compose_email').keys.sample.to_sym
    required_feature = AccountSettings::SettingsConfig[setting][:feature_dependency]
    is_setting_enabled = @account.has_feature?(setting)
    @account.add_feature(setting)
    assert @account.has_feature?(setting)
    is_required_feature_enabled = @account.has_feature?(required_feature)
    @account.add_feature(required_feature)
    assert @account.has_feature?(required_feature)
    # when
    @account.reset_setting(setting)
    # then
    assert @account.changes.key?('plan_features')
    assert_equal @account.send("#{setting}_enabled?"), false
    assert Account.find(@account.id).send("#{setting}_enabled?")
  ensure
    @account.reset_plan_features!
    is_setting_enabled ? @account.add_feature(setting) : @account.revoke_feature(setting)
    is_required_feature_enabled ? @account.add_feature(required_feature) : @account.revoke_feature(required_feature)
  end

  def test_reset_setting_without_dependent_feature
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
      @account.reset_setting(setting)
      assert @account.has_feature?(setting)
    end
  ensure
    is_setting_enabled ? @account.add_feature(setting) : @account.revoke_feature(setting)
    is_required_feature_enabled ? @account.add_feature(required_feature) : @account.revoke_feature(required_feature)
  end

  def test_setting_enabled_method
    # setup
    setting = AccountSettings::SettingsConfig.except('compose_email').keys.sample.to_sym
    required_feature = AccountSettings::SettingsConfig[setting][:feature_dependency]
    is_setting_enabled = @account.has_feature?(setting)
    is_required_feature_enabled = @account.has_feature?(required_feature)
    @account.add_feature(required_feature)
    # when + then
    @account.enable_setting(setting)
    assert @account.send("#{setting}_enabled?")
    @account.disable_setting(setting)
    assert_equal @account.send("#{setting}_enabled?"), false
  ensure
    is_setting_enabled ? @account.add_feature(setting) : @account.revoke_feature(setting)
    is_required_feature_enabled ? @account.add_feature(required_feature) : @account.revoke_feature(required_feature)
  end

  def test_setting_enabled_method_without_dependent_feature
    # setup
    # except :compose_email as the method is overridden
    setting = AccountSettings::SettingsConfig.except('compose_email').keys.sample.to_sym
    required_feature = AccountSettings::SettingsConfig[setting][:feature_dependency]
    is_setting_enabled = @account.has_feature?(setting)
    is_required_feature_enabled = @account.has_feature?(required_feature)
    @account.revoke_feature(required_feature)
    @account.add_feature(setting)
    # when + then
    assert_equal @account.send("#{setting}_enabled?"), false
  ensure
    is_setting_enabled ? @account.add_feature(setting) : @account.revoke_feature(setting)
    is_required_feature_enabled ? @account.add_feature(required_feature) : @account.revoke_feature(required_feature)
  end

  def test_lp_and_bitmap_enable_with_enable_settings
    # setup
    feature = Account::LP_TO_BITMAP_MIGRATION_FEATURES.sample
    is_launched = @account.launched?(feature)
    @account.rollback(feature)
    bitmap_enabled = @account.has_feature?(feature)
    @account.revoke_feature(feature)
    # when
    @account.enable_setting(feature)
    # then
    assert @account.launched?(feature)
    assert @account.has_feature?(feature)
  ensure
    is_launched ? @account.launch(feature) : @account.rollback(feature)
    bitmap_enabled ? @account.add_feature(feature) : @account.revoke_feature(feature)
  end

  def test_lp_and_bitmap_disable_with_disable_settings
    # setup
    feature = Account::LP_TO_BITMAP_MIGRATION_FEATURES.sample
    is_launched = @account.launched?(feature)
    @account.launch(feature)
    bitmap_enabled = @account.has_feature?(feature)
    @account.add_feature(feature)
    # when
    @account.disable_setting(feature)
    # then
    assert_equal @account.launched?(feature), false
    assert_equal @account.has_feature?(feature), false
  ensure
    is_launched ? @account.launch(feature) : @account.rollback(feature)
    bitmap_enabled ? @account.add_feature(feature) : @account.revoke_feature(feature)
  end

  def test_fetch_all_features_enabled
    all_features = @account.features_list
    features_enabled = @account.enabled_features
    enabled_admin_settings = @account.enabled_admin_settings
    enabled_internal_settings = @account.enabled_internal_settings
    assert_equal features_enabled.count, (all_features - enabled_admin_settings - enabled_internal_settings).count
  end

  def test_fetch_admin_settings_enabled
    enabled_admin_settings = @account.enabled_admin_settings
    @account.enable_setting(:disable_freshchat)
    enabled_admin_settings_after_enable = @account.enabled_admin_settings
    assert_equal enabled_admin_settings_after_enable.count, enabled_admin_settings.count + 1
  ensure
    @account.disable_setting(:disable_freshchat)
  end

  def test_fetch_internal_settings_enabled
    enabled_internal_settings = @account.enabled_internal_settings
    @account.enable_setting(:fetch_ticket_from_ref_first)
    enabled_internal_settings_after_enable = @account.enabled_internal_settings
    assert_equal enabled_internal_settings_after_enable.count, enabled_internal_settings.count + 1
  ensure
    @account.disable_setting(:fetch_ticket_from_ref_first)
  end

  # Modify these test when we refactor settings methods
  def test_disable_setting_with_invalid_value_doesnt_raise_error
    @account.disable_setting(:abcd)
  end

  def test_enable_setting_with_invalid_value_doesnt_raise_error
    @account.enable_setting(:abcd)
  end

  def test_set_setting_with_invalid_value_doesnt_raise_error
    @account.disable_setting(:abcd)
  end

  def test_reset_setting_with_invalid_value_doesnt_raise_error
    @account.enable_setting(:abcd)
  end
end
