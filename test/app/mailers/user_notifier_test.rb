require_relative '../../test_helper'
['facebook_helper.rb'].each { |file| require Rails.root.join('spec', 'support', file) }
require "#{Rails.root}/spec/support/agent_helper.rb"
class UserNotifierTest < ActionView::TestCase
  include FacebookHelper
  include AgentHelper
  include EmailHelper

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

  def test_notify_webhook_failure
    recipient1 = add_agent_to_account(@account, name: Faker::Name.name, active: 1, role: 1).user
    recipient2 = add_agent_to_account(@account, name: Faker::Name.name, active: 1, role: 1).user
    recipient1.update_attributes(language: 'de')
    emails = [recipient1.email, recipient2.email]
    mail_message = UserNotifier.send_email_to_group(:notify_webhook_failure, emails, @account, {}, 'example.com')
    assert_equal mail_message['de'].first, recipient1.email
    assert_equal mail_message['en'].first, recipient2.email
  ensure
    recipient1.destroy
    recipient2.destroy
  end

  def test_notify_webhook_drop
    recipient1 = add_agent_to_account(@account, name: Faker::Name.name, active: 1, role: 1).user
    recipient2 = add_agent_to_account(@account, name: Faker::Name.name, active: 1, role: 1).user
    recipient1.update_attributes(language: 'de')
    emails = [recipient1.email, recipient2.email]
    mail_message = UserNotifier.send_email_to_group(:notify_webhook_drop, emails, @account)
    assert_equal mail_message['de'].first, recipient1.email
    assert_equal mail_message['en'].first, recipient2.email
  ensure
    recipient1.destroy
    recipient2.destroy
  end

  def test_failure_transaction_notifier
    recipient = @account.users.find_by_email(@account.admin_email)
    I18n.locale = recipient.language
    mail_message = UserNotifier.send_email(:failure_transaction_notifier, @account.admin_email, @account.admin_email, {:available_passes => 1, :domain => @account.full_domain,
     :admin_name => @account.admin_first_name, :card_details => 'XXXX XXXX XXXX 3456'})
    assert_equal mail_message.to.first, recipient.email
    assert_equal mail_message.subject, 'Payment failed for auto recharge of day passes'
  ensure
    I18n.locale = 'de'
  end

  def test_notify_proactive_outreach_import
    recipient = add_agent_to_account(@account, name: Faker::Name.name, active: 1, role: 1).user
    I18n.locale = recipient.language
    options = { import_success: true, user: recipient, outreach_name: 'sample', failed_count: 0, success_count: 10 }
    mail_message = UserNotifier.send_email(:notify_proactive_outreach_import, recipient.email, options)
    assert_equal recipient.email, mail_message.to.first
    assert_equal 'Outreach in progress', mail_message.subject
    html_part = mail_message.html_part ? mail_message.html_part.body.decoded : nil
    if html_part.present?
      test_part = 'Your import is complete'
      assert_equal html_part.include?(test_part), true
    end
  ensure
    I18n.locale = 'de'
  end

  def test_notify_customers_import
    recipient = add_agent_to_account(@account, name: Faker::Name.name, active: 1, role: 1).user
    I18n.locale = recipient.language
    options = { user: recipient, type: 'tickets', created_count: 10, updated_count: 5, failed_count: 0, import_success: true }
    mail_message = UserNotifier.send_email(:notify_customers_import, recipient.email, options)
    assert_equal recipient.email, mail_message.to.first
    assert_equal "Tickets import for #{@account.full_domain}", mail_message.subject
    html_part = mail_message.html_part ? mail_message.html_part.body.decoded : nil
    if html_part.present?
      test_part = 'Your import has been successfully completed'
      assert_equal html_part.include?(test_part), true
    end
  ensure
    I18n.locale = 'de'
  end

  def test_notify_skill_import
    recipient = User.current || add_agent_to_account(@account, name: Faker::Name.name, active: 1, role: 1).user.make_current
    I18n.locale = recipient.language
    mail_message = UserNotifier.send_email(:notify_skill_import, recipient.email, {})
    assert_equal recipient.email, mail_message.to.first
    assert_equal "Skills Import for #{@account.full_domain}", mail_message.subject
  ensure
    I18n.locale = 'de'
  end

  def test_notify_email_rate_limit_exceeded
    recipient1 = add_agent_to_account(@account, name: Faker::Name.name, active: 1, role: 1, language: 'de').user
    recipient2 = add_agent_to_account(@account, name: Faker::Name.name, active: 1, role: 1).user
    emails = [recipient1.email, recipient2.email]
    mail_message = UserNotifier.send_email_to_group(:notify_email_rate_limit_exceeded, emails)
    assert_equal mail_message['de'].first, recipient1.email
    assert_equal mail_message['en'].first, recipient2.email
  end
end
