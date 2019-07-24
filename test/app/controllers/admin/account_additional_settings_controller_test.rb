require_relative '../../../api/test_helper'
class Admin::AccountAdditionalSettingsControllerTest < ActionController::TestCase
  def test_enable_skip_mandatory
    @agent.stubs(:privilege?).returns(true)
    post :enable_skip_mandatory, version: 'private', format: 'json'
    assert_response 204
    assert_equal true, @account.account_additional_settings.additional_settings[:skip_mandatory_checks]
  ensure
    @account.account_additional_settings.additional_settings[:skip_mandatory_checks] = false
    @account.account_additional_settings.save
    @agent.unstub(:privilege?)
  end

  def test_disable_skip_mandatory
    @agent.stubs(:privilege?).returns(true)
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
end
