require_relative '../../test_helper'
['facebook_helper.rb'].each { |file| require Rails.root.join('spec', 'support', file) }
class UserNotifierTest < ActionView::TestCase
  include FacebookHelper

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

  def test_admin_activation
    recipient = add_agent(@account)
    I18n.locale = recipient.language
    mail_message = UserNotifier.send_email(:admin_activation, recipient, recipient)
    assert_equal recipient.email, mail_message.to.first
    assert_equal "Activate your #{AppConfig['app_name']} account", mail_message.subject
    html_part = mail_message.html_part ? mail_message.html_part.body.decoded : nil
    if html_part.present?
      test_part = 'Thank you for signing up for Freshdesk'
      assert_equal html_part.include?(test_part), true
    end
  ensure
    I18n.locale = 'de'
  end

  def test_custom_ssl_activation
    mail_message = UserNotifier.send_email(:deliver_custom_ssl_activation, @account.admin_email, @account, Faker::Internet.domain_name, 'test-elb')
    assert_equal @account.admin_email, mail_message.to.first
    assert_equal 'Custom SSL Activated', mail_message.subject
    html_part = mail_message.html_part ? mail_message.html_part.body.decoded : nil
    if html_part.present?
      test_part = 'Your request for a custom SSL certificate has been approved.'
      assert_equal html_part.include?(test_part), true
    end
  ensure
    I18n.locale = 'de'
  end

  def test_notify_facebook_reauth
    fb_page = create_test_facebook_page(@account)
    mail_message = UserNotifier.send_email(:notify_facebook_reauth, @account.admin_email, fb_page)
    assert_equal @account.admin_email, mail_message.to.first
    assert_equal 'Need Attention, Facebook app should be reauthorized', mail_message.subject
    html_part = mail_message.html_part ? mail_message.html_part.body.decoded : nil
    if html_part.present?
      test_part = "The access token for your #{fb_page.page_name} page has expired."
      assert_equal html_part.include?(test_part), true
    end
  ensure
    I18n.locale = 'de'
  end
end
