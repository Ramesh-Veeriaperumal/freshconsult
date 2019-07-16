require_relative '../../test_helper'
require_relative '../../api/helpers/test_class_methods.rb'

['forum_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }


class TopicTest < ActiveSupport::TestCase
  include ForumHelper

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

  def test_new_topic_in_forum
    recipient = add_agent(@account)
    category = create_test_category
    forum = create_test_forum(category)
    monitor_forum(forum, recipient)
    topic = create_test_topic(forum)
    topic.published = true
    topic.save
    assert Delayed::Job.last.present?
    assert Delayed::Job.last.handler.include?('CLASS:TopicMailer')
    assert Delayed::Job.last.handler.include?('method: :monitor_email')
  end

  def test_stamp_change_notification
    recipient = add_agent(@account)
    category = create_test_category
    forum = create_test_forum(category)
    topic = create_test_topic(forum)
    monitor_topic(topic, recipient)
    monitor = topic.monitorships.first

    mail_message = TopicMailer.send_email(:stamp_change_email, recipient, recipient.email, topic, topic.user, topic.stamp, topic.type_name, monitor.portal, *monitor.sender_and_host)
    assert_equal recipient.email, mail_message.to.first
    assert_equal "[Status Update] in #{topic.title}", mail_message.subject
  end

  def test_topic_merge_notification
    recipient = add_agent(@account)
    category = create_test_category
    forum = create_test_forum(category)
    topic1 = create_test_topic(forum)
    topic2 = create_test_topic(forum)
    monitor_topic(topic1, recipient)
    monitor = topic1.monitorships.last
    mail_message = TopicMailer.send_email(:deliver_topic_merge_email, recipient, monitor, topic2, topic1, *monitor.sender_and_host)
    assert_equal recipient.email, mail_message.to.first
    assert_equal "[Topic Merged] to #{topic2.title}", mail_message.subject
  end
end