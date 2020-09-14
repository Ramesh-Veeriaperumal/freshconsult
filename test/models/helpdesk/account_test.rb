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
end
