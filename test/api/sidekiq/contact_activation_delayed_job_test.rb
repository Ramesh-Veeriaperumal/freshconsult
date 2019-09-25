require_relative '../unit_test_helper'
require 'sidekiq/testing'
require 'faker'

Sidekiq::Testing.fake!

class ContactActivationDelayedJobTest < ActionView::TestCase
  def setup
    Account.stubs(:current).returns(Account.first || create_test_account)
  end

  def teardown
    Account.unstub(:current)
    super
  end

  def test_contact_activation_user_not_found_error
    object = UserNotifier
    method = 'deliver_user_activation'
    contact = FactoryGirl.build(:user, account: Account.current, email: Faker::Internet.email, user_role: 3)
    contact.save
    performable_method = Delayed::PerformableMethod.new(object, method, [contact], Account.current, nil)
    contact.reload
    contact.destroy
    assert_raises(Delayed::UserNotFoundException) do
      performable_method.perform
    end
  end

  def test_contact_activation_different_method
    object = UserNotifier
    method = 'password_reset_instructions'
    contact = FactoryGirl.build(:user, account: Account.current, email: Faker::Internet.email, user_role: 3)
    contact.save
    performable_method = Delayed::PerformableMethod.new(object, method, [contact], Account.current, nil)
    contact.reload
    contact.destroy
    assert_equal false, performable_method.perform
  end
end
