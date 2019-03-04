require_relative '../../unit_test_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!
require Rails.root.join('test', 'api', 'helpers', 'bot_response_test_helper.rb')

class MlBotFeedbackTest < ActionView::TestCase
  include BotResponseTestHelper

  def setup
    super
    $redis_others.perform_redis_op('set', 'ARTICLE_SPAM_REGEX', '(gmail|kindle|face.?book|apple|microsoft|google|aol|hotmail|aim|mozilla|quickbooks|norton).*(support|phone|number)')
    $redis_others.perform_redis_op('set', 'PHONE_NUMBER_SPAM_REGEX', '(1|I)..?8(1|I)8..?85(0|O)..?78(0|O)6|(1|I)..?877..?345..?3847|(1|I)..?877..?37(0|O)..?3(1|I)89|(1|I)..?8(0|O)(0|O)..?79(0|O)..?9(1|I)86|(1|I)..?8(0|O)(0|O)..?436..?(0|O)259|(1|I)..?8(0|O)(0|O)..?969..?(1|I)649|(1|I)..?844..?922..?7448|(1|I)..?8(0|O)(0|O)..?75(0|O)..?6584|(1|I)..?8(0|O)(0|O)..?6(0|O)4..?(1|I)88(0|O)|(1|I)..?877..?242..?364(1|I)|(1|I)..?844..?782..?8(0|O)96|(1|I)..?844..?895..?(0|O)4(1|I)(0|O)|(1|I)..?844..?2(0|O)4..?9294|(1|I)..?8(0|O)(0|O)..?2(1|I)3..?2(1|I)7(1|I)|(1|I)..?855..?58(0|O)..?(1|I)8(0|O)8|(1|I)..?877..?424..?6647|(1|I)..?877..?37(0|O)..?3(1|I)89|(1|I)..?844..?83(0|O)..?8555|(1|I)..?8(0|O)(0|O)..?6(1|I)(1|I)..?5(0|O)(0|O)7|(1|I)..?8(0|O)(0|O)..?584..?46(1|I)(1|I)|(1|I)..?844..?389..?5696|(1|I)..?844..?483..?(0|O)332|(1|I)..?844..?78(0|O)..?675(1|I)|(1|I)..?8(0|O)(0|O)..?596..?(1|I)(0|O)65|(1|I)..?888..?573..?5222|(1|I)..?855..?4(0|O)9..?(1|I)555|(1|I)..?844..?436..?(1|I)893|(1|I)..?8(0|O)(0|O)..?89(1|I)..?4(0|O)(0|O)8|(1|I)..?855..?662..?4436')
    $redis_others.perform_redis_op('set', 'CONTENT_SPAM_CHAR_REGEX', 'ℴ|ℕ|ℓ|ℳ|ℱ|ℋ|ℝ|ⅈ|ℯ|ℂ|○|ℬ|ℂ|ℙ|ℹ|ℒ|ⅉ|ℐ|ℰ|ℭ|ℍ|𝒾|ℛ')
    Account.stubs(:current).returns(Account.first)
    @account = Account.current
    @bot = @account.main_portal.bot || create_test_email_bot({email_channel: true})
    @agent = get_admin()
    @bot_response = create_sample_bot_response(nil, @bot.id, nil, construct_suggested_articles)
    @ml_bot_feedback = Bot::Emailbot::MlBotFeedback.new
  end

  def teardown
    Account.unstub(:current)
    super
  end

  def test_ml_bot_feedback
    payloads_count = 1
    stub_method_count = 0
    @ml_bot_feedback.safe_send('create_connection').stub :post, -> { stub_method_count+=1; Faraday::Response.new(status: 202, body: {}) } do
      @ml_bot_feedback.perform(bot_response_id: @bot_response.id, article_meta_id: @@articles.first.id)
    end
    assert_equal payloads_count, stub_method_count
  ensure
    @ml_bot_feedback.safe_send('create_connection').unstub(:post)
  end

  def test_ml_payload_request_body
    payload = construct_central_payload(@bot_response, @@articles.first.id)
    request_body = @ml_bot_feedback.safe_send('request_body',payload)
    assert_equal request_body, construct_request_body(@bot_response, @@articles.first.id)
  end

  def test_ml_bot_feedback_with_401_from_central
    assert_nothing_raised do
      @ml_bot_feedback.safe_send('create_connection').stub :post, -> { Faraday::Response.new(status: 401, body: {}) } do
        @ml_bot_feedback.perform(bot_response_id: @bot_response.id, article_meta_id: @@articles.first.id)
      end
    end
  ensure
    @ml_bot_feedback.safe_send('create_connection').unstub(:post)
  end

  def test_ml_bot_feedback_with_exception_handled
    assert_nothing_raised do
      Bot::Response.any_instance.stubs(:usefulness).raises(RuntimeError)
      @ml_bot_feedback.safe_send('create_connection').stub :post, -> { Faraday::Response.new(status: 202, body: {}) } do
        @ml_bot_feedback.perform(bot_response_id: @bot_response.id, article_meta_id: @@articles.first.id)
      end
    end
  ensure
    Bot::Response.any_instance.unstub(:usefulness)
    @ml_bot_feedback.safe_send('create_connection').unstub(:post)
  end
end
