# frozen_string_literal: true

require_relative '../../../../api/api_test_helper'
['contact_fields_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }

class Support::ProfilesControllerFlowTest < ActionDispatch::IntegrationTest
  include ContactFieldsHelper

  # ------------------ edit ------------------------ #

  def test_edit_without_current_user
    UserSession.any_instance.unstub(:cookie_credentials)
    account_wrap do
      get 'support/profile/edit'
    end
    assert_response 302
    assert_redirected_to '/login'
    assert_template nil
    assert_equal I18n.t(:'flash.general.need_login'), flash[:notice]
  end

  def test_edit_when_helpdesk_agent_is_false
    User.any_instance.stubs(:helpdesk_agent?).returns(false)
    account_wrap do
      get 'support/profile/edit'
    end
    assert_response 200
    assert_template :edit
    assert_equal response.redirection?, false
    assert_equal @agent, assigns[:profile]
    assert_equal @agent, assigns[:current_user]
  ensure
    User.any_instance.unstub(:helpdesk_agent?)
  end

  def test_edit_when_helpdesk_agent_is_true
    account_wrap do
      get 'support/profile/edit'
    end
    assert_response 302
    assert_redirected_to "/profiles/#{@agent.id}/edit"
    assert_template nil
  end

  # ------------------ update ------------------------ #

  def test_update_without_current_user
    UserSession.any_instance.unstub(:cookie_credentials)
    account_wrap do
      put 'support/profile'
    end
    assert_response 302
    assert_redirected_to '/login'
    assert_template nil
    assert_equal I18n.t(:'flash.general.need_login'), flash[:notice]
  end

  def test_update_when_helpdesk_agent_is_true
    account_wrap do
      put 'support/profile'
    end
    assert_response 302
    assert_redirected_to "/profiles/#{@agent.id}/edit"
    assert_template nil
  end

  def test_update_when_helpdesk_agent_is_false_multilingual_is_false
    user = add_new_user(@account, language: 'en')
    set_request_auth_headers(user)
    Portal.any_instance.stubs(:multilingual?).returns(false)
    user_params = { language: 'fr' }
    account_wrap do
      put 'support/profile', user: user_params
    end
    user.reload
    assert_response 302
    assert_redirected_to '/support/profile/edit'
    assert_template nil
    assert_equal I18n.t(:'flash.profile.update.success'), flash[:notice]
    assert_equal user_params[:language], user.language
  ensure
    Portal.any_instance.unstub(:multilingual?)
  end

  def test_update_when_helpdesk_agent_is_false_multilingual_is_true
    user = add_new_user(@account, language: 'en')
    set_request_auth_headers(user)
    Portal.any_instance.stubs(:multilingual?).returns(true)
    user_params = { language: 'fr' }
    account_wrap do
      put 'support/profile', user: user_params
    end
    user.reload
    assert_response 302
    assert_redirected_to "/#{@account.language}/support/profile"
    assert_template nil
    assert_not_equal user_params[:language], user.language
  ensure
    Portal.any_instance.unstub(:multilingual?)
  end

  def test_update_when_helpdesk_agent_is_false_update_attributes_is_false
    user = add_new_user(@account, language: 'en')
    set_request_auth_headers(user)
    User.any_instance.stubs(:update_attributes).returns(false)
    user_params = { language: 'fr' }
    account_wrap do
      put 'support/profile', user: user_params
    end
    user.reload
    assert_response 200
    assert_equal 'en', user.language
    assert_not_equal user_params[:language], user.language
    assert_template :edit
  ensure
    User.any_instance.unstub(:update_attributes)
  end

  def test_update_clean_params
    user = add_new_user(@account, language: 'en', email: 'old_email@gmail.com')
    set_request_auth_headers(user)
    Portal.any_instance.stubs(:multilingual?).returns(false)
    user_params = { language: 'fr', email: 'new_email@gmail.com' }
    account_wrap do
      put 'support/profile', user: user_params
    end
    user.reload
    assert_response 302
    assert_redirected_to '/support/profile/edit'
    assert_template nil
    assert_equal user_params[:language], user.language
    assert_not_equal user_params[:email], user.email
    assert_equal 'old_email@gmail.com', user.email
  ensure
    Portal.any_instance.unstub(:multilingual?)
  end

  def test_update_remove_noneditable_fields_in_user_params
    user = add_new_user(@account)
    user.description = 'old_desc'
    user.save
    set_request_auth_headers(user)
    Portal.any_instance.stubs(:multilingual?).returns(false)
    ContactField.any_instance.stubs(:editable_in_portal).returns(false)
    user_params = { description: 'new_desc' }
    account_wrap do
      put 'support/profile', user: user_params
    end
    user.reload
    assert_response 302
    assert_redirected_to '/support/profile/edit'
    assert_template nil
    assert_not_equal user_params[:description], user.description
    assert_equal 'old_desc', user.description
  ensure
    Portal.any_instance.unstub(:multilingual?)
    ContactField.any_instance.unstub(:editable_in_portal)
  end

  def test_update_having_no_required_fields
    user = add_new_user(@account, language: 'en')
    set_request_auth_headers(user)
    Portal.any_instance.stubs(:multilingual?).returns(false)
    ContactField.any_instance.stubs(:required_in_portal).returns(false)
    user_params = { language: 'fr' }
    account_wrap do
      put 'support/profile', user: user_params
    end
    user.reload
    assert_response 302
    assert_redirected_to '/support/profile/edit'
    assert_template nil
    assert_equal user_params[:language], user.language
    assert_equal I18n.t(:'flash.profile.update.success'), flash[:notice]
  ensure
    Portal.any_instance.unstub(:multilingual?)
    ContactField.any_instance.unstub(:required_in_portal)
  end

  def test_required_field_sent_as_nil
    old_language = 'en'
    user = add_new_user(@account, language: old_language)
    set_request_auth_headers(user)
    Portal.any_instance.stubs(:multilingual?).returns(false)
    ContactField.any_instance.stubs(:required_in_portal).returns(true)
    user_params = { language: nil }
    account_wrap do
      put 'support/profile', user: user_params
    end
    user.reload
    assert_response 200
    assert_template :edit
    assert_equal old_language, user.language
    assert response.body.include?('Language ' + I18n.t('user.errors.required_field'))
    assert (assigns[:profile].errors.to_h.keys.include? :Language) && (assigns[:profile].errors.to_h.fetch(:Language) == I18n.t('user.errors.required_field')), "Expected error message: '#{I18n.t('user.errors.required_field')}' not found"
  ensure
    Portal.any_instance.unstub(:multilingual?)
    ContactField.any_instance.unstub(:required_in_portal)
  end

  def test_update_remove_noneditable_fields_in_user_params_custom_field
    custom_field = create_contact_field(cf_params(type: 'boolean', field_type: 'custom_checkbox', label: 'Job title', editable_in_signup: 'true'))
    user = add_new_user(@account)
    set_request_auth_headers(user)
    Portal.any_instance.stubs(:multilingual?).returns(false)
    ContactField.any_instance.stubs(:editable_in_portal).returns(false)
    user_params = { custom_field: { custom_field.name => true } }
    account_wrap do
      put 'support/profile', user: user_params
    end
    user.reload
    assert_response 302
    assert_redirected_to '/support/profile/edit'
    assert_template nil
    assert_equal nil, user.custom_field['cf_custom_job_title']
  ensure
    Portal.any_instance.unstub(:multilingual?)
    ContactField.any_instance.unstub(:editable_in_portal)
  end

  def test_custom_fields
    custom_field = create_contact_field(cf_params(type: 'boolean', field_type: 'custom_checkbox', label: 'Job title', editable_in_signup: 'true'))
    user = add_new_user(@account)
    set_request_auth_headers(user)
    Portal.any_instance.stubs(:multilingual?).returns(false)
    user_params = { custom_field: { custom_field.name => true } }
    account_wrap do
      put 'support/profile', user: user_params
    end
    user.reload
    assert_response 302
    assert_redirected_to '/support/profile/edit'
    assert_template nil
    assert_equal I18n.t(:'flash.profile.update.success'), flash[:notice]
    assert_equal true, user.custom_field['cf_custom_job_title']
  ensure
    Portal.any_instance.unstub(:multilingual?)
  end

  private

    def old_ui?
      true
    end
end
