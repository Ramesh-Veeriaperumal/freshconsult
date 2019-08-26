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
end
