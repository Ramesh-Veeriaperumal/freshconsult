require_relative '../../../test_helper'
class Notifications::Email::BccControllerTest < ActionController::TestCase
  def wrap_cname(params)
    {
      bcc: params
    }
  end

  def create_valid_update_params
    {
      emails: [
        'test@test.com',
        'test1@test.com'
      ]
    }
  end

  def setup
    super
    User.any_instance.stubs(:privilege?).with(:manage_email_settings).returns(true)
    @account_bcc_emails = @account.account_additional_settings.bcc_email
  end

  def test_successful_update_of_bcc_emails
    params = create_valid_update_params
    put :update, construct_params({}, params)
    assert_response 200
    match_json(create_valid_update_params)
  end

  def test_update_with_invalid_params
    params = create_valid_update_params
    params[:emails] = ['1234']
    put :update, construct_params({}, params)
    assert_response 400
    match_json([bad_request_error_pattern('emails', 'Invalid email: 1234', code: :invalid_value)])
  end

  def test_update_with_invalid_field_name
    params = create_valid_update_params
    params[:test_bcc_email] = params.delete(:emails)
    put :update, construct_params({}, params)
    assert_response 400
    match_json([bad_request_error_pattern('test_bcc_email', :invalid_field, code: :invalid_field)])
  end

  def test_update_with_duplicates
    params = create_valid_update_params
    params[:emails].push('test1@test.com')
    put :update, construct_params({}, params)
    assert_response 200
    match_json(create_valid_update_params)
  end

  def test_update_with_empty_params
    params = create_valid_update_params
    params[:emails] = []
    put :update, construct_params({}, params)
    assert_response 200
    match_json(emails: [])
  end

  def test_show_bcc_email
    @account_settings = @account.account_additional_settings
    @account_settings.bcc_email = create_valid_update_params[:emails].join(',')
    @account_settings.save!
    get :show, controller_params
    assert_response 200
    match_json(create_valid_update_params)
  end

  def test_update_bcc_without_privilege
    params = create_valid_update_params
    User.any_instance.stubs(:privilege?).with(:manage_email_settings).returns(false)
    put :update, construct_params({}, params)
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  ensure
    User.any_instance.stubs(:privilege?).with(:manage_email_settings).returns(true)
  end

  def test_show_bcc_without_privilege
    User.any_instance.stubs(:privilege?).with(:manage_email_settings).returns(false)
    get :show, controller_params
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  ensure
    User.any_instance.stubs(:privilege?).with(:manage_email_settings).returns(true)
  end

  def teardown
    @account_settings = @account.account_additional_settings
    @account_settings.bcc_email = @account_bcc_emails
    @account_settings.save!
    User.any_instance.unstub(:privilege?)
  end
end
