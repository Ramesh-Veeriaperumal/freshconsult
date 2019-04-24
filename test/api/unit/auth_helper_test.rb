require_relative '../unit_test_helper'

class AuthHelperTest < ActionView::TestCase
  def test_get_email_user_deleted
    account = mock
    account.stubs(:features_included?).returns(false)
    account.stubs(:id).returns(1)
    Account.stubs(:current).returns(account)
    user = mock
    user.stubs(:deleted).returns(true)
    User.expects(:find_by_user_emails).with('sample@freshdesk.com').returns(user).once
    assert_nil AuthHelper.get_email_user('sample@freshdesk.com', 'test', nil)
    Account.unstub(:current)
  end

  def test_get_email_user_invalid
    account = mock
    account.stubs(:features_included?).returns(false)
    account.stubs(:id).returns(1)
    Account.stubs(:current).returns(account)
    assert_nil AuthHelper.get_email_user('absent@freshdesk.com', 'test', nil)
    Account.unstub(:current)
  end

  def test_get_email_user_invalid_password
    account = mock
    account.stubs(:features_included?).returns(false)
    account.stubs(:id).returns(1)
    Account.stubs(:current).returns(account)
    user = mock
    user.stubs(:deleted).returns(false)
    account.stubs(:freshid_enabled?).returns(false)
    account.stubs(:freshid_org_v2_enabled?).returns(false)
    account.stubs(:freshid_integration_enabled?).returns(false)
    user.stubs(:valid_password?).returns(false)
    user.expects(:update_failed_login_count).with(false, 'sample@freshdesk.com', nil).returns(nil)
    User.expects(:find_by_user_emails).with('sample@freshdesk.com').returns(user).once
    assert_nil AuthHelper.get_email_user('sample@freshdesk.com', 'test', nil)
    Account.unstub(:current)
  end

  def test_get_email_user_invalid_fid_password
    account = mock
    account.stubs(:features_included?).returns(false)
    account.stubs(:id).returns(1)
    Account.stubs(:current).returns(account)
    user = mock
    user.stubs(:deleted).returns(false)
    account.stubs(:freshid_enabled?).returns(true)
    account.stubs(:freshid_org_v2_enabled?).returns(false)
    account.stubs(:freshid_integration_enabled?).returns(true)
    user.stubs(:valid_freshid_password?).returns(false)
    user.expects(:update_failed_login_count).with(false, 'sample@freshdesk.com', nil).returns(nil)
    User.expects(:find_by_user_emails).with('sample@freshdesk.com').returns(user).once
    assert_nil AuthHelper.get_email_user('sample@freshdesk.com', 'test', nil)
    Account.unstub(:current)
  end
  
  def test_get_email_user_valid_fid_password
    account = mock
    account.stubs(:features_included?).returns(false)
    account.stubs(:id).returns(1)
    Account.stubs(:current).returns(account)
    user = mock
    user.stubs(:deleted).returns(false)
    user.stubs(:failed_login_count).returns(0)
    account.stubs(:freshid_enabled?).returns(true)
    account.stubs(:freshid_org_v2_enabled?).returns(false)
    account.stubs(:freshid_integration_enabled?).returns(true)
    user.stubs(:valid_freshid_password?).returns(true)
    user.expects(:update_failed_login_count).with(true, 'sample@freshdesk.com', nil).returns(user)
    User.expects(:find_by_user_emails).with('sample@freshdesk.com').returns(user).once
    assert_not_nil AuthHelper.get_email_user('sample@freshdesk.com', 'test', nil)
    Account.unstub(:current)
  end

  def test_get_token_user_invalid
    account = mock
    account.stubs(:features_included?).returns(false)
    account.stubs(:id).returns(1)
    Account.stubs(:current).returns(account)
    assert_nil AuthHelper.get_token_user('wwwtoken')
    Account.unstub(:current)
  end

  def test_get_token_user_deleted
    account = mock
    account.stubs(:features_included?).returns(false)
    account.stubs(:id).returns(1)
    Account.stubs(:current).returns(account)
    user = mock
    user.stubs(:deleted).returns(true)
    User.expects(:where).with(single_access_token: 'wwwtoken').returns([user]).once
    assert_nil AuthHelper.get_token_user('wwwtoken')
    Account.unstub(:current)
  end
end
