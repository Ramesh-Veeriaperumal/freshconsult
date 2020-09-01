require_relative '../../test_helper'
Dir["#{Rails.root}/test/core/functional/helpdesk/accounts_controller_test_cases/*.rb"].each { |file| require file }
class AccountsControllerTest < ActionController::TestCase
  include AccountsControllerTestHelper

  def test_email_signup
    email = Faker::Internet.email
    post :email_signup, email_signup_params({:email => email})
    assert_response 200
    assert_account_created_with_given_email(email)
  end

  def test_email_signup_with_spam_detection_feature
    email = Faker::Internet.email
    post :email_signup, email_signup_params(email: email)
    assert_response 200
    assert_account_created_with_feature(:proactive_spam_detection)
  end

  def test_email_signup_with_same_email_id_and_without_force
    email = Faker::Internet.email
    post :email_signup, email_signup_params({:email => email})
    post :email_signup, email_signup_params({:email => email})
    assert_response 412
  end

  def test_email_signup_with_same_email_id_and_with_force
    email = Faker::Internet.email
    post :email_signup, email_signup_params({:email => email})
    9.times do
      post :email_signup, email_signup_params({:email => email, :force => "true"})
      assert_response 200
      assert_account_created_with_given_email(email)
    end
  end

  def test_email_signup_with_maximum_limit_without_force
    email = Faker::Internet.email
    10.times do
      post :email_signup, email_signup_params({:email => email, :force => "true"})
    end
    post :email_signup, email_signup_params({:email => email})
    assert_response 429
  end

  def test_email_signup_with_maximum_limit_with_force
    email = Faker::Internet.email
    10.times do
      post :email_signup, email_signup_params({:email => email, :force => "true"})
    end
    post :email_signup, email_signup_params({:email => email, :force => "true"})
    assert_response 429

  end

  def test_email_signup_unprocess_entity
    email = Faker::Lorem.characters(10) + '.com'
    post :email_signup, email_signup_params({:email => email})
    assert_response 422
  end

  def test_email_signup_fluffy_email_enabled
    email = Faker::Internet.email
    $redis_others.perform_redis_op('hset', 'CONDITION_BASED_LAUNCHPARTY_FEATURES', 'fluffy_email_signup', true)
    Fluffy::AccountsV2Api.any_instance.stubs(:add_application).returns(true)
    post :email_signup, email_signup_params(:email => email)
    assert_response 200
    assert Account.current.fluffy_email_signup_enabled?
    assert Account.current.fluffy_email_enabled?
  ensure
    $redis_others.perform_redis_op('hdel', 'CONDITION_BASED_LAUNCHPARTY_FEATURES', 'fluffy_email_signup')
    Account.current.rollback(:fluffy_email_signup)
    Account.current.rollback(:fluffy_email)
    Fluffy::AccountsV2Api.any_instance.unstub(:add_application)
  end
end
