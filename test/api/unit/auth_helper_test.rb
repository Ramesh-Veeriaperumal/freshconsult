require_relative '../unit_test_helper'

class AuthHelperTest < ActionView::TestCase
  def test_get_email_user_deleted
    user = mock
    user.stubs(:deleted).returns(true)
    User.expects(:find_by_user_emails).with("sample@freshdesk.com").returns(user).once
    assert_nil AuthHelper.get_email_user("sample@freshdesk.com", "test", nil)
  end

  def test_get_email_user_invalid
    account = mock
    account.stubs(:features_included?).returns(false)
    account.stubs(:id).returns(1)
    Account.stubs(:current).returns(account)
    assert_nil AuthHelper.get_email_user("absent@freshdesk.com", "test", nil)
    Account.unstub(:current)
  end

  def test_get_email_user_invalid_password
    user = mock
    user.stubs(:deleted).returns(false)
    user.stubs(:valid_password?).returns(false)
    user.expects(:update_failed_login_count).with(false, "sample@freshdesk.com", nil).returns(nil)
    User.expects(:find_by_user_emails).with("sample@freshdesk.com").returns(user).once
    assert_nil AuthHelper.get_email_user("sample@freshdesk.com", "test", nil)
  end

  def test_get_token_user_invalid
    account = mock
    account.stubs(:features_included?).returns(false)
    account.stubs(:id).returns(1)
    Account.stubs(:current).returns(account)
    assert_nil AuthHelper.get_token_user("wwwtoken")
    Account.unstub(:current)
  end

  def test_get_token_user_deleted
    user = mock
    user.stubs(:deleted).returns(true)
    User.expects(:where).with({single_access_token: "wwwtoken"}).returns([user]).once
    assert_nil AuthHelper.get_token_user("wwwtoken")
  end

end
