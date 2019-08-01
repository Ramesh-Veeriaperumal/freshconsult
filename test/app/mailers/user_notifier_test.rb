require_relative '../../test_helper'
class UserNotifierTest < ActionView::TestCase
  def setup
    super
    @account = create_test_account if @account.nil?
    @account.make_current
    @account.tags.delete_all
    @account.tag_uses.delete_all
    Account.stubs(:multi_language_enabled?).returns(true)
    I18n.locale = 'de'
    Account.current.stubs(:language).returns('de')
  end

  def teardown
    I18n.locale = I18n.default_locale
    Account.current.unstub(:language)
    Account.unstub(:multi_language_enabled?)
  end

  def test_notify_dkim_activation
    recipient = @account.users.find_by_email(@account.admin_email)
    I18n.locale = recipient.language
    dkim_details = { 'email_domain': 'example.com' }
    mail_message = UserNotifier.send_email(:notify_dkim_activation, recipient.email, @account, dkim_details)
    assert_equal recipient.email, mail_message.to.first
    assert_equal 'DKIM signatures activation email', mail_message.subject
    html_part = mail_message.html_part ? mail_message.html_part.body.decoded : nil
    if html_part.present?
      test_part = 'DKIM signatures are now activated'
      assert_equal html_part.include?(test_part), true
    end
  ensure
    I18n.locale = 'de'
  end

  def test_notify_dkim_failure
    recipient = @account.users.find_by_email(@account.admin_email)
    I18n.locale = recipient.language
    dkim_details = { 'email_domain': 'example.com' }
    mail_message = UserNotifier.send_email(:notify_dkim_failure, recipient.email, @account, dkim_details)
    assert_equal recipient.email, mail_message.to.first
    assert_equal 'DKIM signatures activation email', mail_message.subject
    html_part = mail_message.html_part ? mail_message.html_part.body.decoded : nil
    if html_part.present?
      test_part = 'DKIM verification failed'
      assert_equal html_part.include?(test_part), true
    end
  ensure
    I18n.locale = 'de'
  end
end
