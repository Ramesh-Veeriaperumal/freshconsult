require_relative '../../unit_test_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!
require Rails.root.join('test', 'api', 'helpers', 'bot_response_test_helper.rb')

class MlBotFeedbackTest < ActionView::TestCase
  include BotResponseTestHelper

  def setup
    super
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
