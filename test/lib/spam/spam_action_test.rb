require_relative '../../api/unit_test_helper'
['account_test_helper.rb'].each { |file| require Rails.root.join("test/core/helpers/#{file}") }

class SpamActionFakeController < ApplicationController
  include Spam::SpamAction

  def current_account
    Account.current
  end

  def current_user
    User.current
  end

  def content
    Faker::Lorem.word
  end

  def extract_subject_and_message
    [Faker::Lorem.word, Faker::Lorem.word]
  end

  def check_valid_template
    validate_template_content(Faker::Lorem.word, Faker::Lorem.paragraphs, 1)
    head 200
  end

  def check_detect_spam
    detect_spam_action
    head 200
  end

  def check_template_spam
    @email_notification = Account.current.email_notifications.first
    template_spam_check
    head 200
  end
end

class SpamActionFakeControllerTest < ActionController::TestCase
  include AccountTestHelper

  def setup
    @account = Account.current
    @user = @account.nil? ? create_test_account : @account.users.find { |user| !user.email.nil? }
    User.stubs(:current).returns(@user)
  end

  def teardown
    User.unstub(:current)
    super
  end

  def test_validate_template_content
    response = ActionDispatch::TestResponse.new
    @controller.response = response
    @controller.stubs(:action_name).returns('check_valid_template')
    actual = @controller.send(:check_valid_template)
    assert_response 200
  end

  def test_detect_a_spam_action
    Account.any_instance.stubs(:created_at).returns(2.days.ago)
    ActiveRecord::Relation.any_instance.stubs(:count).returns(2)
    $redis_others.perform_redis_op('sadd', 'SPAM_USER_EMAIL_DOMAINS', @user.email.split('@').last.downcase)
    response = ActionDispatch::TestResponse.new
    @controller.response = response
    @controller.stubs(:action_name).returns('check_detect_spam')
    actual = @controller.send(:check_detect_spam)
    assert_response 200
  ensure
    Account.any_instance.unstub(:created_at)
    ActiveRecord::Relation.any_instance.unstub(:count)
    $redis_others.perform_redis_op('del', 'SPAM_USER_EMAIL_DOMAINS')
  end

  def test_spam_action_with_account_created_before_7_days
    $redis_others.perform_redis_op('sadd', 'SPAM_USER_EMAIL_DOMAINS', User.current.email.split('@').last.downcase)
    Account.any_instance.stubs(:created_at).returns(4.days.ago)
    response = ActionDispatch::TestResponse.new
    @controller.response = response
    @controller.stubs(:action_name).returns('check_detect_spam')
    actual = @controller.send(:check_detect_spam)
    assert_response 200
  ensure
    $redis_others.perform_redis_op('del', 'SPAM_USER_EMAIL_DOMAINS')
    Account.any_instance.unstub(:created_at)
  end

  def test_spam_action_with_account_created_long_back
    $redis_others.perform_redis_op('sadd', 'SPAM_USER_EMAIL_DOMAINS', User.current.email.split('@').last.downcase)
    Account.any_instance.stubs(:created_at).returns(10.days.ago)
    Spam::SpamCheck.any_instance.stubs(:has_more_redirection_links?).returns(true)
    response = ActionDispatch::TestResponse.new
    @controller.response = response
    @controller.stubs(:action_name).returns('check_detect_spam')
    actual = @controller.send(:check_detect_spam)
    assert_response 200
  ensure
    $redis_others.perform_redis_op('del', 'SPAM_USER_EMAIL_DOMAINS')
    Account.any_instance.unstub(:created_at)
  end

  def test_check_template_spam
    response = ActionDispatch::TestResponse.new
    @controller.response = response
    @controller.stubs(:action_name).returns('check_template_spam')
    actual = @controller.send(:check_template_spam)
    assert_response 200
  end
end
