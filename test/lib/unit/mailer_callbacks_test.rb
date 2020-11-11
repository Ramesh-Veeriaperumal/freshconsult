require_relative '../test_helper'
require_relative '../../api/helpers/test_class_methods.rb'

['forum_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }


class MailerCallbacksTest < ActiveSupport::TestCase
  include ForumHelper

  def setup
    super
    @account = create_test_account if @account.nil?
    @account.make_current
    @account.tags.delete_all
    @account.tag_uses.delete_all
    Account.stubs(:multi_language_enabled?).returns(true)
  end

  def teardown
    I18n.locale = I18n.default_locale
    Account.unstub(:multi_language_enabled?)
  end

  def test_enqueue_delayed_job_with_locale
    recipient = add_agent(@account)
    category = create_test_category
    forum = create_test_forum(category)
    monitor_forum(forum, recipient)
    topic = create_test_topic(forum)
    topic.published = true
    topic.save
    assert Delayed::Job.last.handler.include?('CLASS:TopicMailer')
    assert Delayed::Job.last.handler.include?('method: :monitor_email')
  end

  def test_email_without_translation
    recipient = add_agent(@account)
    category = create_test_category
    forum = create_test_forum(category)
    topic = create_test_topic(forum)
    monitor_topic(topic, recipient)
    monitor = topic.monitorships.first
    I18n.locale = 'de'
    Account.current.stubs(:language).returns('de')
    mail_message = TopicMailer.stamp_change_email(recipient.email, topic, topic.user, topic.stamp, topic.type_name, monitor.portal, *monitor.sender_and_host)
    assert_equal recipient.email, mail_message.to.first
    assert_not_equal "[Status Update] in #{topic.title}", mail_message.subject
  ensure
    Account.current.unstub(:language)
    I18n.locale = 'en'
  end

  def test_translate_email_in_user_locale
    recipient = add_agent(@account)
    category = create_test_category
    forum = create_test_forum(category)
    topic = create_test_topic(forum)
    monitor_topic(topic, recipient)
    monitor = topic.monitorships.first

    I18n.locale = 'de'
    Account.current.stubs(:language).returns('de')
    assert_equal 'en', recipient.language
    mail_message = TopicMailer.send_email(:stamp_change_email, recipient, recipient.email, topic, topic.user, topic.stamp, topic.type_name, monitor.portal, *monitor.sender_and_host)
    assert_equal recipient.email, mail_message.to.first
    assert_equal "[Status Update] in #{topic.title}", mail_message.subject

    assert_equal :de, I18n.locale
   ensure
    Account.current.unstub(:language)
    I18n.locale = 'en'
  end

  def test_translate_email_in_absence_of_user_language
    recipient = add_agent(@account)
    recipient.stubs(:language).returns(nil)
    category = create_test_category
    forum = create_test_forum(category)
    topic = create_test_topic(forum)
    monitor_topic(topic, recipient)
    monitor = topic.monitorships.first

    I18n.locale = 'en'
    Account.current.stubs(:language).returns('en')
    Portal.current.stubs(:language).returns('en') if Portal.current
    assert_equal nil, recipient.language
    mail_message = TopicMailer.send_email(:stamp_change_email, recipient, recipient.email, topic, topic.user, topic.stamp, topic.type_name, monitor.portal, *monitor.sender_and_host)
    assert_equal recipient.email, mail_message.to.first
    assert_equal "[Status Update] in #{topic.title}", mail_message.subject

    assert_equal :en, I18n.locale


    I18n.locale = 'de'
    Account.current.stubs(:language).returns('de')
    Portal.current.stubs(:language).returns('de') if Portal.current
    assert_equal nil, recipient.language
    mail_message = TopicMailer.send_email(:stamp_change_email, recipient, recipient.email, topic, topic.user, topic.stamp, topic.type_name, monitor.portal, *monitor.sender_and_host)
    assert_equal recipient.email, mail_message.to.first
    assert_not_equal "[Status Update] in #{topic.title}", mail_message.subject

    assert_equal :de, I18n.locale
  ensure
    recipient.unstub(:language)
    Account.current.unstub(:language)
    Portal.current.unstub(:language) if Portal.current
    I18n.locale = 'en'
  end

  def test_translate_email_in_account_language
    recipient = add_agent(@account)
    recipient.stubs(:language).returns('de')
    category = create_test_category
    forum = create_test_forum(category)
    topic = create_test_topic(forum)
    monitor_topic(topic, recipient)
    monitor = topic.monitorships.first

    I18n.locale = 'en'
    Account.current.stubs(:language).returns('en')
    assert_equal 'de', recipient.language
    mail_message = TopicMailer.send_email(:stamp_change_email, recipient, recipient.email, topic, topic.user, topic.stamp, topic.type_name, monitor.portal, *monitor.sender_and_host)
    assert_equal recipient.email, mail_message.to.first
    assert_not_equal "[Status Update] in #{topic.title}", mail_message.subject

    assert_equal :en, I18n.locale
  ensure
    recipient.unstub(:language)
    Account.current.unstub(:language)
    I18n.locale = 'en'
  end

  def test_send_email_to_group
    Account.current.stubs(:language).returns('de')
    Portal.current.stubs(:language).returns('de') if Portal.current
    recipient1 = add_agent(@account)
    recipient2 = 'test@email.random'
    to_emails = [recipient1.email, recipient2]
    mail_message = ScheduledTaskMailer.send_email_to_group(:report_no_data_email_message, to_emails)
    assert_equal mail_message['de'].first, recipient2
    assert_equal mail_message['en'].first, recipient1.email
  ensure
    Account.current.unstub(:language)
    Portal.current.unstub(:language) if Portal.current
    recipient1.destroy
  end

  def test_send_email_to_group_with_empty_emails
    Account.current.stubs(:language).returns('de')
    to_emails = []
    mail_message = ScheduledTaskMailer.send_email_to_group(:report_no_data_email_message, to_emails)
    assert_equal mail_message['de'].first, nil
  ensure
    Account.current.unstub(:language)
  end

  def test_send_email_with_input
    I18n.locale = 'de'
    mail_message = UserNotifier.send_email(:notify_dkim_activation, @account.admin_email, @account, 'email_domain' => 'testdomain.com')
    assert_equal mail_message.to.first, @account.admin_email
    assert_equal :de, I18n.locale
  end
end
