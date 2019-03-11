require_relative '../unit_test_helper'
class ActionMailerCallbacksTest < ActiveSupport::TestCase
  def test_get_email_type_txn
    res = ActionMailer::Base.get_email_type 'Reply'
    assert_equal 'TRANSACTION', res
  end

  def test_get_email_type_ntf
    res = ActionMailer::Base.get_email_type 'Internal Email'
    assert_equal 'NOTIFICATION', res
  end

  def test_get_email_type_system
    res = ActionMailer::Base.get_email_type 'Data Backup'
    assert_equal 'SYSTEM', res
  end

  def test_account_type
    Account.first.make_current
    exp = Account.current.subscription.state.upcase
    res = ActionMailer::Base.get_account_type
    Account.reset_current_account
    assert_equal exp, res
  end

  def test_account_type_default
    res = ActionMailer::Base.get_account_type
    assert_equal 'MONITORING', res
  end
end
