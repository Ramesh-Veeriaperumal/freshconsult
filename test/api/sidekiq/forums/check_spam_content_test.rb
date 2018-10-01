require_relative '../../unit_test_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
require Rails.root.join('test', 'api', 'helpers', 'discussions_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'controller_test_helper.rb')

class CheckSpamContentTest < ActionView::TestCase
  include AccountTestHelper
  include DiscussionsTestHelper
  include ControllerTestHelper
  include Redis::RedisKeys
  include Redis::PortalRedis

  def setup
    Account.stubs(:current).returns(Account.first)
    @account = Account.current
    @agent = get_admin
    @customer = create_dummy_customer
    @agent.make_current
    @topic = create_test_topic(Forum.first)
    $redis_others.perform_redis_op("set", "PHONE_NUMBER_SPAM_REGEX", "(1|I)..?8(1|I)8..?85(0|O)..?78(0|O)6|(1|I)..?877..?345..?3847|(1|I)..?877..?37(0|O)..?3(1|I)89|(1|I)..?8(0|O)(0|O)..?79(0|O)..?9(1|I)86|(1|I)..?8(0|O)(0|O)..?436..?(0|O)259|(1|I)..?8(0|O)(0|O)..?969..?(1|I)649|(1|I)..?844..?922..?7448|(1|I)..?8(0|O)(0|O)..?75(0|O)..?6584|(1|I)..?8(0|O)(0|O)..?6(0|O)4..?(1|I)88(0|O)|(1|I)..?877..?242..?364(1|I)|(1|I)..?844..?782..?8(0|O)96|(1|I)..?844..?895..?(0|O)4(1|I)(0|O)|(1|I)..?844..?2(0|O)4..?9294|(1|I)..?8(0|O)(0|O)..?2(1|I)3..?2(1|I)7(1|I)|(1|I)..?855..?58(0|O)..?(1|I)8(0|O)8|(1|I)..?877..?424..?6647|(1|I)..?877..?37(0|O)..?3(1|I)89|(1|I)..?844..?83(0|O)..?8555|(1|I)..?8(0|O)(0|O)..?6(1|I)(1|I)..?5(0|O)(0|O)7|(1|I)..?8(0|O)(0|O)..?584..?46(1|I)(1|I)|(1|I)..?844..?389..?5696|(1|I)..?844..?483..?(0|O)332|(1|I)..?844..?78(0|O)..?675(1|I)|(1|I)..?8(0|O)(0|O)..?596..?(1|I)(0|O)65|(1|I)..?888..?573..?5222|(1|I)..?855..?4(0|O)9..?(1|I)555|(1|I)..?844..?436..?(1|I)893|(1|I)..?8(0|O)(0|O)..?89(1|I)..?4(0|O)(0|O)8|(1|I)..?855..?662..?4436")
    $redis_others.perform_redis_op("set", "CONTENT_SPAM_CHAR_REGEX", "ℴ|ℕ|ℓ|ℳ|ℱ|ℋ|ℝ|ⅈ|ℯ|ℂ|○|ℬ|ℂ|ℙ|ℹ|ℒ|ⅉ|ℐ|ℰ|ℭ|ℍ|𝒾|ℛ")
  end

  def teardown
    Account.unstub(:current)
    super
  end

  def test_topic_title_without_spam
    response = Forum::CheckContentForSpam.new.perform(topic_id: @topic.id)
    assert_equal response, false
  end

  def test_topic_title_with_spam
    @topic.title = "gmail support phone" # Spammed content
    @topic.save!
    FreshdeskErrorsMailer.stubs(:error_email).returns(nil)
    portal_redis_version = portal_redis_key
    response = Forum::CheckContentForSpam.new.perform(topic_id: @topic.id)
    assert_equal response, true
    assert_equal portal_redis_key.to_i, portal_redis_version.to_i+1
  ensure
    FreshdeskErrorsMailer.unstub(:error_email)
  end

  def test_topic_title_with_phone_number_spam
    @topic.title = "phone number is 1/S/8446922/S/7448" # Spammed content
    @topic.save!
    FreshdeskErrorsMailer.stubs(:error_email).returns(nil)
    portal_redis_version = portal_redis_key
    response = Forum::CheckContentForSpam.new.perform(topic_id: @topic.id)
    assert_equal response, true
    assert_equal portal_redis_key.to_i, portal_redis_version.to_i+1
  ensure
    FreshdeskErrorsMailer.unstub(:error_email)
  end

  def test_topic_title_with_special_characters_spam
    @topic.title = "Special character is ℬℙℳ" # Spammed content
    @topic.save!
    FreshdeskErrorsMailer.stubs(:error_email).returns(nil)
    portal_redis_version = portal_redis_key
    response = Forum::CheckContentForSpam.new.perform(topic_id: @topic.id)
    assert_equal response, true
    assert_equal portal_redis_key.to_i, portal_redis_version.to_i+1
  ensure
    FreshdeskErrorsMailer.unstub(:error_email)
  end

  def test_post_description_without_spam
    post = create_test_post(@topic)
    response = Forum::CheckContentForSpam.new.perform(post_id: post.id, topic_id: @topic.id)
    assert_equal response, false
  end

  def test_post_description_with_spam
    post = create_test_post(@topic)
    post.body_html = "<p>gmail support phone</p>" # Spammed content
    post.save!
    FreshdeskErrorsMailer.stubs(:error_email).returns(nil)
    portal_redis_version = portal_redis_key
    response = Forum::CheckContentForSpam.new.perform(post_id: post.id, topic_id: @topic.id)
    assert_equal response, true
    assert_equal portal_redis_key.to_i, portal_redis_version.to_i+1
  ensure
    FreshdeskErrorsMailer.unstub(:error_email)
  end

  def test_post_description_with_phone_number_spam
    post = create_test_post(@topic)
    post.body_html = "<p>phone number is 1/S/8446922/S/7448</p>" # Spammed content
    post.save!
    FreshdeskErrorsMailer.stubs(:error_email).returns(nil)
    portal_redis_version = portal_redis_key
    response = Forum::CheckContentForSpam.new.perform(post_id: post.id, topic_id: @topic.id)
    assert_equal response, true
    assert_equal portal_redis_key.to_i, portal_redis_version.to_i+1
  ensure
    FreshdeskErrorsMailer.unstub(:error_email)
  end

  def test_post_description_with_special_characters_spam
    post = create_test_post(@topic)
    post.body_html = "<p>Special character is ℬℙℳ</p>" # Spammed content
    post.save!
    FreshdeskErrorsMailer.stubs(:error_email).returns(nil)
    portal_redis_version = portal_redis_key
    response = Forum::CheckContentForSpam.new.perform(post_id: post.id, topic_id: @topic.id)
    assert_equal response, true
    assert_equal portal_redis_key.to_i, portal_redis_version.to_i+1
  ensure
    FreshdeskErrorsMailer.unstub(:error_email)
  end

  private

    def portal_redis_key
      get_portal_redis_key(PORTAL_CACHE_VERSION % { :account_id => Account.current.id })
    end
end