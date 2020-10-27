# frozen_string_literal:true

require_relative '../../api/test_helper'
class Support::LoginControllerTest < ActionController::TestCase
  def setup
    @account = Account.first.presence || create_test_account
    super
  end

  def teardown
    Account.reset_current_account
    super
  end

  def test_support_login_when_restricted_helpdesk_login_fail_is_true
    controller.params[:restricted_helpdesk_login_fail] = true
    controller.safe_send('set_custom_flash_message')
    expected = "<div align= 'center'> #{I18n.t(:'flash.login.login_permission_denied')}. <br> #{I18n.t(:'flash.login.contact_administrator')} </div>"
    assert_equal expected, flash[:notice]
  end
end
