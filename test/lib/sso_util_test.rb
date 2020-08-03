require_relative '../api/test_helper'

class SsoUtilTestController < ApplicationController
  include SsoUtil
  include ActionController::Renderers::All

  def sso_login_page
    sso_login_page_redirect
    head 200
  end

  def sso_user_fields
    populate_sso_user_fields(Account.first, User.last, User.last.attributes, {}, false)
    head 200
  end

  def sso_response_handling(sso_data)
    handle_sso_response(sso_data, nil)
    head 200
  end

  def saml_response_validation
    validate_saml_response(Account.first, nil)
    head 200
  end

  def user_jwt_sso
    update_user_for_jwt_sso(Account.first, User.last, User.last.attributes, {}, false)
    head 200
  end
end

class SsoUtilTestControllerTest < ActionController::TestCase
  include SsoUtil

  def test_valid_saml_on_initialize
    saml = SAMLResponse.new(true, 'user_name', 'user_name@email.com',
                            0, nil, nil, nil, {},
                            'error_message')
    assert_equal saml.valid?, true
  end

  def test_sso_login_page
    Account.any_instance.stubs(:sso_options).returns(sso_options)
    response = ActionDispatch::TestResponse.new
    @controller.response = response
    @controller.stubs(:action_name).returns('sso_login_page')
    actual = @controller.send(:sso_login_page)
    assert_response 200
  ensure
    Account.any_instance.unstub(:sso_options)
  end

  def test_sso_login_with_saml
    response = ActionDispatch::TestResponse.new
    Account.any_instance.stubs(:is_saml_sso?).returns(true)
    OneLogin::RubySaml::Settings.any_instance.stubs(:idp_sso_target_url).returns('')
    @controller.response = response
    @controller.stubs(:action_name).returns('sso_login_page')
    actual = @controller.send(:sso_login_page)
    assert_response 200
  end

  def test_populate_sso_user_fields
    response = ActionDispatch::TestResponse.new
    @controller.response = response
    @controller.stubs(:action_name).returns('sso_user_fields')
    actual = @controller.send(:sso_user_fields)
    assert_response 200
  end

  def test_handle_sso_response
    response = ActionDispatch::TestResponse.new
    @controller.response = response
    Account.any_instance.stubs(:sso_enabled?).returns(true)
    UserSession.any_instance.stubs(:save).returns(true)
    @controller.stubs(:create_user).returns(
      User.new(name: sso_data[:name], email: sso_data[:email],
               phone: sso_data[:phone], helpdesk_agent: false, language: 'en')
    )
    @controller.stubs(:remove_old_filters).returns(true)
    @controller.stubs(:action_name).returns('sso_response_handling')
    actual = @controller.send(:sso_response_handling, sso_data)
    assert_response 200
  end

  def test_handle_sso_response_save_fail
    response = ActionDispatch::TestResponse.new
    @controller.response = response
    Account.any_instance.stubs(:sso_enabled?).returns(true)
    UserSession.any_instance.stubs(:save).returns(false)
    @controller.stubs(:create_user).returns(
      User.new(name: sso_data[:name], email: sso_data[:email],
               phone: sso_data[:phone], helpdesk_agent: false, language: 'en')
    )
    @controller.stubs(:action_name).returns('sso_response_handling')
    actual = @controller.send(:sso_response_handling, sso_data)
    assert_response 200
  end

  def test_validate_saml_response_error
    response = ActionDispatch::TestResponse.new
    @controller.response = response
    OneLogin::RubySaml::Response.stubs(:new).returns(User.last)
    User.any_instance.stubs(:settings).returns(User.last)
    User.any_instance.stubs(:issuer=).returns(true)
    User.any_instance.stubs(:is_valid?).returns(false)
    @controller.stubs(:action_name).returns('saml_response_validation')
    actual = @controller.send(:saml_response_validation)
    assert_response 200
  end

  def test_validate_saml_response_invalid
    response = ActionDispatch::TestResponse.new
    @controller.response = response
    OneLogin::RubySaml::Response.stubs(:new).returns(User.last)
    User.any_instance.stubs(:settings).returns(User.last)
    User.any_instance.stubs(:issuer=).returns(true)
    User.any_instance.stubs(:is_valid?).returns(false)
    User.any_instance.stubs(:document).returns('')
    @controller.stubs(:action_name).returns('saml_response_validation')
    actual = @controller.send(:saml_response_validation)
    assert_response 200
  end

  def test_validate_saml_response_valid
    response = ActionDispatch::TestResponse.new
    @controller.response = response
    OneLogin::RubySaml::Response.stubs(:new).returns(User.last)
    User.any_instance.stubs(:settings).returns(User.last)
    User.any_instance.stubs(:issuer=).returns(true)
    User.any_instance.stubs(:is_valid?).returns(true)
    User.any_instance.stubs(:name_id).returns(User.last.email)
    @controller.stubs(:action_name).returns('saml_response_validation')
    actual = @controller.send(:saml_response_validation)
    assert_response 200
  end

  def test_update_user_for_jwt_sso
    response = ActionDispatch::TestResponse.new
    @controller.response = response
    @controller.stubs(:action_name).returns('user_jwt_sso')
    actual = @controller.send(:user_jwt_sso)
    assert_response 200
  end

  def test_validate_custom_field_date
    validation_response = validate_custom_field('field_name', 12, Date)
  rescue SsoFieldValidationError => e
    assert_equal validation_response, nil
  end

  def test_validate_custom_field_boolean
    validation_response = validate_custom_field('field_name', 'something', 'Boolean')
  rescue SsoFieldValidationError => e
    assert_equal validation_response, nil
  end

  def test_validate_custom_field_url
    validation_response = validate_custom_field('field_name', 12, 'URL')
  rescue SsoFieldValidationError => e
    assert_equal validation_response, nil
  end

  def test_validate_custom_field_fixnum
    validation_response = validate_custom_field('field_name', 'abcd', Fixnum)
  rescue SsoFieldValidationError => e
    assert_equal validation_response, nil
  end

  def test_validate_custom_field_others
    validation_response = validate_custom_field('field_name', 12, 'RandomType')
  rescue SsoFieldValidationError => e
    assert_equal validation_response, nil
  end

  private

    def sso_data
      {
        email: User.last.email,
        name: User.last.name,
        phone: User.last.phone,
        company: nil,
        title: nil,
        external_id: nil
      }
    end

    def sso_options
      {
        login_url: 'test.freshdesk.com/sso'
      }
    end
end
