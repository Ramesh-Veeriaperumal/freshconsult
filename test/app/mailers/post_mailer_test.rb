require_relative '../../test_helper'
['forum_helper.rb'].each { |file| require Rails.root.join('spec', 'support', file) }

class PostMailerTest < ActionMailer::TestCase
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

  def test_monitor_email
    recipient = add_agent(@account, language: 'en')
    category = create_test_category
    forum = create_test_forum(category)
    topic = create_test_topic(forum, recipient)
    topic.save
    monitor_topic(topic, recipient)
    monitorship = topic.monitorships.first
    post = topic.posts.first
    mail_message = PostMailer.send_email(:monitor_email, monitorship.user, monitorship.user.email, post, post.user, monitorship.portal, *monitorship.sender_and_host)
    assert_equal mail_message.to.first, recipient.email
    assert mail_message.subject.include?('[New Reply]')
    html_part = mail_message.html_part ? mail_message.html_part.body.decoded : nil
    if html_part.present?
      test_part = 'Reply notifications for this topic'
      assert html_part.include?(test_part)
    end
    assert_equal :de, I18n.locale
  ensure
    topic.destroy
    forum.destroy
    category.destroy
    recipient.destroy
  end
end
