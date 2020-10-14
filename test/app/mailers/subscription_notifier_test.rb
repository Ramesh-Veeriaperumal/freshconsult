require_relative '../../test_helper'
require Rails.root.join('test', 'models', 'helpers', 'subscription_test_helper.rb')

class SubscriptionNotifierTest < ActionView::TestCase
  include SubscriptionTestHelper

  def setup
    super
    @account = create_test_account if @account.nil?
    @account.make_current
    @account.tags.delete_all
    @account.tag_uses.delete_all
    Account.stubs(:multi_language_enabled?).returns(true)
    I18n.locale = 'de'
  end

  def teardown
    I18n.locale = I18n.default_locale
    Account.unstub(:multi_language_enabled?)
  end

  def test_admin_spam_watcher
    user1 = add_agent(@account)
    user2 = add_agent(@account)
    deleted_users = [user1, user2]
    mail_message = SubscriptionNotifier.send_email(:deliver_admin_spam_watcher, @account.admin_email, @account, deleted_users)
    assert_equal mail_message.to.first, @account.admin_email
    assert_equal mail_message.subject, 'Freshdesk :: Spam watcher'
    email_body = mail_message.body.present? ? mail_message.body.decoded : nil
    if email_body.present?
      test_part = 'Below listed users are blocked by our spam watcher'
      assert_equal email_body.include?(test_part), true
    end
    assert_equal :de, I18n.locale
  ensure
    user1.destroy
    user2.destroy
  end

  def test_admin_spam_watcher_blocked
    mail_message = SubscriptionNotifier.send_email(:deliver_admin_spam_watcher_blocked, @account.admin_email, @account)
    assert_equal mail_message.to.first, @account.admin_email
    assert_equal mail_message.subject, 'Freshdesk :: Spam watcher'
    email_body = mail_message.body.present? ? mail_message.body.decoded : nil
    if email_body.present?
      test_part = 'Your Account has been blocked due to high volume of traffic'
      assert_equal email_body.include?(test_part), true
    end
    assert_equal :de, I18n.locale
  end

  def test_admin_account_cancelled
    I18n.locale = I18n.default_locale
    user1 = add_agent(@account)
    user2 = add_agent(@account)
    admin_emails = { group: [user1.email, user2.email], other: ['random1@xyz.com'] }
    mail_message = SubscriptionNotifier.admin_account_cancelled(admin_emails)
    assert_equal mail_message.to.first, user1.email
    assert_equal mail_message.subject, "#{@account.full_domain} has been cancelled (#{@account.id})"
    email_body = mail_message.body.present? ? mail_message.body.decoded : nil
    if email_body.present?
      test_part = 'Freshdesk account has been cancelled'
      assert_equal email_body.include?(test_part), true
    end
  ensure
    user1.destroy
    user2.destroy
  end

  def test_account_cancellation_requested_email
    user1 = add_agent(@account)
    chargebee_update = ChargeBee::Result.new(stub_update_params(@account.id))
    ChargeBee::Subscription.stubs(:retrieve).returns(chargebee_update)
    mail_message = SubscriptionNotifier.account_cancellation_requested({}, user1)
    assert_equal mail_message.subject, "Cancellation request from #{@account.full_domain} (#{@account.id})"
    test_part = 'placed a request to cancel the account just now.'
    assert_equal mail_message.body.decoded.include?(test_part), true
  ensure
    user1.destroy
  end
end
