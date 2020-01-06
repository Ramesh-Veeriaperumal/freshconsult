require_relative '../test_helper'
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')

class AccountTest < ActiveSupport::TestCase
  include AccountTestHelper

  def test_account_find_with_valid_account_id
    user = create_test_account
    account = user.account
    Rails.logger.debug "Account helper inspection #{account.inspect}"
    assert_equal Account.find(account.id), account
  end

  def test_account_not_found_custom_error_for_invalid_account_id
    invalid_id = Account.maximum(:id) + 100
    assert_raises Account::RecordNotFound do
      Account.find(invalid_id)
    end
  end

  def test_enable_secure_attachments
    @account = create_test_account if @account.nil?
    @account.make_current
    @account.revoke_feature(:private_inline)
    @account.add_feature(:secure_attachments)
    assert @account.private_inline_enabled?
  ensure
    @account.revoke_feature(:secure_attachments)
  end

  def test_disable_secure_attachments
    @account = create_test_account if @account.nil?
    @account.make_current
    @account.add_feature(:secure_attachments)
    @account.add_feature(:private_inline)
    @account.revoke_feature(:secure_attachments)
    assert !@account.private_inline_enabled?
  ensure
    @account.revoke_feature(:private_inline)
  end

  def test_launch_groups_with_additonalsettings_groups_add_remove_set_get
    Sharding.select_shard_of(@account.id) do
      @account = create_test_account if @account.nil?
      @account.make_current
      @account.account_additional_settings.additional_settings[:launchgroups] = ['group1', 'group2']
      @account.account_additional_settings.save
      assert @account.launchgroups.sort == [@account.plan_name.to_s, ActiveRecord::Base.current_shard_selection.shard.to_s, @account.subscription.state.to_s, "group1", "group2"].sort
      @account.add_launchgroups('group2')
      assert @account.account_additional_settings.additional_settings[:launchgroups].sort == ['group1', 'group2'].sort
      @account.add_launchgroups(['group3', 'group4'])
      assert @account.account_additional_settings.additional_settings[:launchgroups].sort == ['group1', 'group2', 'group3', 'group4'].sort
      @account.remove_launchgroups('group4')
      assert @account.account_additional_settings.additional_settings[:launchgroups].sort == ['group1', 'group2', 'group3'].sort
      @account.remove_launchgroups(['group2','group3'])
      assert @account.account_additional_settings.additional_settings[:launchgroups] == ['group1']
      @account.account_additional_settings.additional_settings = nil
      @account.account_additional_settings.save
      @account.remove_launchgroups('group2')
      @account.add_launchgroups('group2')
      assert @account.account_additional_settings.additional_settings[:launchgroups] == ['group2']
    end  
  end

  def test_handle_exception
    @account = create_test_account if @account.nil?
    @account.make_current
    assert @account.launched?(nil) == false
  end
end
