require_relative '../../test_helper.rb'
require_relative '../../api/helpers/test_class_methods.rb'
require_relative '../../core/helpers/account_test_helper.rb'
require Rails.root.join('spec', 'support', 'user_helper.rb')
require Rails.root.join('spec', 'support', 'forum_helper.rb')

class ReportExportMailerTest < ActionMailer::TestCase
  include AccountTestHelper
  include UsersHelper
  include ForumHelper

  def setup
    super
    create_test_account if @account.nil?
    Account.current.stubs(:language).returns('fr')
  end

  def teardown
    Account.current.unstub(:language)
    super
  end

  def test_notify_topic_new_follower
    en_subject = I18n.t('mailer_notifier_subject.notify_new_topic_follower')
    en_body    = I18n.t('mailer_notifier.notify_new_follower.topic.message')
    subject_bk = I18n.t('mailer_notifier_subject.notify_new_topic_follower', locale: :fr)
    body_bk    = I18n.t('mailer_notifier.notify_new_follower.topic.message', locale: :fr)
    I18n.backend.store_translations('fr', mailer_notifier_subject: { notify_new_topic_follower: "$0$#{en_subject}" })
    I18n.backend.store_translations('fr', mailer_notifier: { notify_new_follower: { topic: { message: "$0$#{en_body}" } } })
    I18n.locale = 'en'
    follower = add_agent(@account)
    follower.language = 'fr'
    category = create_test_category
    forum = create_test_forum(category)
    topic = create_test_topic(forum)
    monitorship = Monitorship.new
    monitorship.user = follower
    monitorship.stubs(:get_portal).returns(Account.current.main_portal)
    email = TopicMailer.send_email(:notify_new_follower, follower, topic, follower, monitorship)
    assert_equal true, email.subject.include?('$0$')
    assert_equal true, email.subject.include?('Topic')
    assert_equal true, email.body.encoded.include?('$0$')
    assert_equal true, email.body.encoded.include?('topic')
    assert_equal true, email.body.encoded.include?(follower.name)
    assert_equal true, I18n.locale.to_s.eql?('en')
    I18n.backend.store_translations('fr', mailer_notifier_subject: { notify_new_topic_follower: subject_bk })
    I18n.backend.store_translations('fr', mailer_notifier: { notify_new_follower: { topic: { message: body_bk } } })
  end

  def test_notify_forum_new_follower
    en_subject = I18n.t('mailer_notifier_subject.notify_new_forum_follower')
    en_body    = I18n.t('mailer_notifier.notify_new_follower.forum.message')
    subject_bk = I18n.t('mailer_notifier_subject.notify_new_forum_follower', locale: :fr)
    body_bk    = I18n.t('mailer_notifier.notify_new_follower.forum.message', locale: :fr)
    I18n.backend.store_translations('fr', mailer_notifier_subject: { notify_new_forum_follower: "$0$#{en_subject}" })
    I18n.backend.store_translations('fr', mailer_notifier: { notify_new_follower: { forum: { message: "$0$#{en_body}" } } })
    I18n.locale = 'en'
    follower = add_agent(@account)
    follower.language = 'fr'
    category = create_test_category
    forum = create_test_forum(category)
    monitorship = Monitorship.new
    monitorship.user = follower
    monitorship.stubs(:get_portal).returns(Account.current.main_portal)
    email = ForumMailer.send_email(:notify_new_follower, follower, forum, follower, monitorship)
    assert_equal true, email.subject.include?('$0$')
    assert_equal true, email.subject.include?('Forum')
    assert_equal true, email.body.encoded.include?('$0$')
    assert_equal true, email.body.encoded.include?('forum')
    assert_equal true, email.body.encoded.include?(follower.name)
    assert_equal true, I18n.locale.to_s.eql?('en')
    I18n.backend.store_translations('fr', mailer_notifier_subject: { notify_new_forum_follower: subject_bk })
    I18n.backend.store_translations('fr', mailer_notifier: { notify_new_follower: {forum:{ message: body_bk } } })
  end

  def test_notify_forum_new_follower_delayed
    follower = add_agent(@account)
    follower.language = 'fr'
    category = create_test_category
    forum = create_test_forum(category)
    monitorship = Monitorship.new
    monitorship.user = follower
    monitorship.stubs(:get_portal).returns(Account.current.main_portal)
    ForumMailer.send_later(:notify_new_follower, forum, follower, monitorship, locale_object: follower)
    assert Delayed::Job.last.handler.include?('method: :notify_new_follower')
    assert Delayed::Job.last.handler.include?('locale_object:')
    assert Delayed::Job.last.handler.include?('language: fr')
  end

end
