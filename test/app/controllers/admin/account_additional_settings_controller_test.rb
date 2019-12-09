require_relative '../../../api/test_helper'
class Admin::AccountAdditionalSettingsControllerTest < ActionController::TestCase
  def test_enable_disable_skip_mandatory
    @agent.stubs(:privilege?).returns(true)
    post :enable_skip_mandatory, version: 'private', format: 'json'
    assert_response 204
    assert_equal true, @account.account_additional_settings.additional_settings[:skip_mandatory_checks]
    @account.account_additional_settings.additional_settings[:skip_mandatory_checks] = true
    @account.account_additional_settings.save
    post :disable_skip_mandatory, version: 'private', format: 'json'
    assert_response 204
    @account.account_additional_settings.reload
    assert_equal false, @account.account_additional_settings.additional_settings[:skip_mandatory_checks]
  ensure
    @account.account_additional_settings.additional_settings[:skip_mandatory_checks] = false
    @account.account_additional_settings.save
    @agent.unstub(:privilege?)
  end

  def test_update_font_with_params_passed
    @account.account_additional_settings.additional_settings[:email_template] = { 'font-family' => 'arial black, sans-serif', 'font-size' => '13px' }
    @account.account_additional_settings.save
    @request.env['HTTP_ACCEPT'] = 'application/javascript'
    params = { 'font-family': 'tahoma, arial, sans-serif', 'font-size': '16px' }
    put :update_font, params
    assert_response 200
    @account.account_additional_settings.reload
    assert_equal @account.account_additional_settings.additional_settings[:email_template], params.stringify_keys
  end

  def test_update_font_when_font_size_param_not_passed
    @account.account_additional_settings.additional_settings[:email_template] = { 'font-family' => 'arial black, sans-serif' }
    @account.account_additional_settings.save
    @request.env['HTTP_ACCEPT'] = 'application/javascript'
    params = { 'font-family': 'garamond, serif' }
    put :update_font, params
    assert_response 200
    # when font-size is not passed as a param, the default font style should be taken from DEFAULTS_FONT_SETTINGS in account_constants.rb
    # this default font-size value is set in additional_settings column in account_additional_settings table
    expected_result = { 'font-family': 'garamond, serif', 'font-size': '14px' }
    @account.account_additional_settings.reload
    assert_equal @account.account_additional_settings.additional_settings[:email_template], expected_result.stringify_keys
  end

  def test_update_font_when_font_family_param_not_passed
    @account.account_additional_settings.additional_settings[:email_template] = { 'font-size' => '17px' }
    @account.account_additional_settings.save
    @request.env['HTTP_ACCEPT'] = 'application/javascript'
    params = { 'font-size': '20px' }
    put :update_font, params
    assert_response 200
    # when font-family is not passed as a param, the default font style should be taken from DEFAULTS_FONT_SETTINGS
    expected_result = { 'font-family': '-apple-system, BlinkMacSystemFont, Segoe UI, Roboto, Helvetica Neue, Arial, sans-serif', 'font-size': '20px' }
    @account.account_additional_settings.reload
    assert_equal @account.account_additional_settings.additional_settings[:email_template], expected_result.stringify_keys
  end
end
