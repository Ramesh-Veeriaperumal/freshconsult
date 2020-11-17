# frozen_string_literal: true

require_relative '../../api/api_test_helper'
['user_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }

class ActivationsControllerFlowTest < ActionDispatch::IntegrationTest
  include UsersHelper

  def test_send_invite_to_user_as_an_admin
    user = add_new_user(@account, active: false)
    account_wrap do
      put "/activations/#{user.id}/send_invite", nil, 'HTTP_REFERER' => 'http://localhost.freshpo.com'
    end
    assert session['flash'][:notice].include?('Activation email has been sent!')
    assert Delayed::Job.last.handler.include?('user_activation')
  end

  def test_send_invite_to_user_as_an_admin_format_js
    user = add_new_user(@account, active: false)
    account_wrap do
      put "/activations/#{user.id}/send_invite", { format: 'js' }, 'HTTP_REFERER' => 'http://localhost.freshpo.com'
    end
    assert Delayed::Job.last.handler.include?('user_activation')
    assert_equal({ 'activation_sent' => true }, JSON.parse(response.body))
  end

  def test_valid_activation_code
    user = add_new_user(@account, active: false)
    user.reset_perishable_token!
    account_wrap do
      get "/register/#{user.perishable_token}"
    end
    assert_response 200
    assert response.body.include?('Activate your account')
  end

  def test_invalid_activation_code
    user = add_new_user(@account, active: false)
    old_perishable_token = user.perishable_token
    user.reset_perishable_token!
    account_wrap do
      get "/register/#{old_perishable_token}"
    end
    assert_response 302
    assert session['flash'][:notice].include?('Your activation code has been expired!')
    assert_equal 'http://localhost.freshpo.com/password_resets/new', response.location
  end

  def test_activate_new_email
    user = add_user_with_multiple_emails(@account, 4)
    user.active = false
    user.save!
    user = User.find(user.id)
    account_wrap do
      put "/register_new_email/#{user.user_emails.first.perishable_token}"
    end
    assert_response 200
    assert response.body.include?('<h3 class="heading">Activate your account')
  end

  def test_invalid_token_for_new_email
    user = add_user_with_multiple_emails(@account, 4)
    user.active = false
    user.save!
    account_wrap do
      put "/register_new_email/#{SecureRandom.hex}"
    end
    assert_response 302
    assert_equal 'http://localhost.freshpo.com/home', response.location
    assert session['flash'][:notice].include?('Your activation code has been expired!')
  end

  def test_already_activated_email
    user = add_new_user(@account, active: true)
    account_wrap do
      put "/register_new_email/#{user.user_emails.last.perishable_token}"
    end
    assert_response 302
    assert_equal 'http://localhost.freshpo.com/home', response.location
    assert session['flash'][:notice].include?('email id already activated')
  end

  def test_new_email_activate
    user = add_new_user(@account, active: true)
    user_email = user.user_emails.last
    user_email.update_attribute(:verified, false)
    account_wrap do
      put "/register_new_email/#{user.user_emails.last.perishable_token}"
    end
    user_email.reload
    assert user_email.verified?
    assert_response 302
    assert_equal 'http://localhost.freshpo.com/home', response.location
    assert session['flash'][:notice].include?('New email id has been activated')
  end

  def test_activate_user
    user = add_new_user(@account, active: false)
    account_wrap do
      post '/activations', perishable_token: user.perishable_token, user: { name: user.name, password: 'hello1234', password_confirmation: 'hello1234' }
    end
    user.reload
    assert user.active
    assert_response 302
    assert_equal 'http://localhost.freshpo.com/', response.location
    assert session['flash'][:notice].include?('Your account has been activated.')
  end

  def test_activate_invalid_user
    user = add_new_user(@account, active: false)
    account_wrap do
      post '/activations', perishable_token: SecureRandom.hex, user: { name: user.name, password: 'hello1234', password_confirmation: 'hello1234' }
    end
    assert_response 302
    assert_equal 'http://localhost.freshpo.com/support/login', response.location
    assert session['flash'][:notice].include?('You are not allowed to access this page!')
  end

  def test_activate_failed
    user = add_new_user(@account, active: false)
    User.any_instance.stubs(:activate!).returns(false)
    account_wrap do
      post '/activations', perishable_token: user.perishable_token, user: { name: user.name, password: 'hello1234', password_confirmation: 'hello1234' }
    end
    assert_response 200
    assert response.body.include?('Activate your account')
  ensure
    User.any_instance.unstub(:activate!)
  end

  def test_activate_exception
    user = add_new_user(@account, active: false)
    User.any_instance.stubs(:activate!).raises(StandardError)
    account_wrap do
      post '/activations', perishable_token: user.perishable_token, user: { name: user.name, password: 'hello1234', password_confirmation: 'hello1234' }
    end
    assert_response 200
    assert response.body.include?('Activate your account')
  ensure
    User.any_instance.unstub(:activate!)
  end

  private

    def old_ui?
      true
    end
end
