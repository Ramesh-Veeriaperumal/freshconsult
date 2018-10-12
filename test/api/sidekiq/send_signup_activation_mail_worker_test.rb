require_relative '../unit_test_helper'
require 'sidekiq/testing'
require 'minitest/autorun'

Sidekiq::Testing.fake!

class SendSignupActivationMailTest < ActionView::TestCase

  def teardown
    Account.unstub(:current)
    super
  end

  def setup
    Account.stubs(:current).returns(Account.first)
    @account = Account.current
  end

  def test_send_signup_activation_mail
    assert_nothing_raised do
      SendSignupActivationMail.new.perform({account_id: Account.current.id, user_id: Account.current.users.first.id})
    end
  end
end