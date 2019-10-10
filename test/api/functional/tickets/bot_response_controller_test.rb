require_relative '../../test_helper'

class Tickets::BotResponseControllerTest < ActionController::TestCase
  include ApiTicketsTestHelper
  include ApiBotTestHelper
  include BotResponseTestHelper

  def setup
    super
    @ticket = create_ticket
    @bot = create_bot({ product: true})
    @bot_responses = create_bot_response(@ticket.id, @bot.id)
  end

  def teardown
    @ticket.destroy
    @bot.destroy if @bot
  end
  ###############UPDATE BOT RESPONSE##############

  ###############BOT EMAIL CHANNEL################ 
  def test_bot_response_update
    enable_agent_articles_suggest do
      params_hash = { articles: [{ id: @bot_responses.suggested_articles.keys[0].to_i, agent_feedback: false }] }
      put :update, construct_params(version: 'private', id: @ticket.display_id, bot_response: params_hash)
      assert_response 200
      match_json(bot_response_pattern(@bot_responses, params_hash))
    end
  end

  def test_bot_response_update_empty
    enable_agent_articles_suggest do
      params_hash = {}
      put :update, construct_params(version: 'private', id: @ticket.display_id, bot_response: params_hash)
      assert_response 400
      match_json(request_error_pattern(:missing_params))
    end
  end

  def test_bot_response_update_invalid_key
    enable_agent_articles_suggest do
      params_hash = { article: [{ id: @bot_responses.suggested_articles.keys[0].to_i, agent_feedback: false }] }
      put :update, construct_params(version: 'private', id: @ticket.display_id, bot_response: params_hash)
      assert_response 400
      match_json([bad_request_error_pattern('article', :invalid_field)])
    end
  end

  def test_bot_response_update_empty_value
    enable_agent_articles_suggest do
      params_hash = { articles: [] }
      put :update, construct_params(version: 'private', id: @ticket.display_id, bot_response: params_hash)
      assert_response 400
      match_json([bad_request_error_pattern('articles', :"can't be blank", code: :invalid_value)])
    end
  end

  def test_bot_response_update_invalid_article_keys
    enable_agent_articles_suggest do
      params_hash = { articles: [{ id: @bot_responses.suggested_articles.keys[0].to_i, agent_feedbacks: false }, 
        { ids: @bot_responses.suggested_articles.keys[1].to_i, agent_feedback: false }] }
      put :update, construct_params(version: 'private', id: @ticket.display_id, bot_response: params_hash)
      assert_response 400
      match_json([bad_request_error_pattern('articles[0][agent_feedback]', :missing_field),
        bad_request_error_pattern('articles[0][agent_feedbacks]', :invalid_field),
        bad_request_error_pattern('articles[1][id]', :missing_field),
        bad_request_error_pattern('articles[1][ids]', :invalid_field)])
    end
  end

  def test_bot_response_update_article_with_invalid_id_datatype
    enable_agent_articles_suggest do
      params_hash = { articles: [{ id: @bot_responses.suggested_articles.keys[0].to_s, agent_feedback: false }] }
      put :update, construct_params(version: 'private', id: @ticket.display_id, bot_response: params_hash)
      assert_response 400
      match_json([bad_request_error_pattern_with_nested_field('articles', 'id', :"It should be a/an Positive Integer", code: :datatype_mismatch)])
    end
  end


  def test_bot_response_update_article_with_invalid_agent_feedback_datatype
    enable_agent_articles_suggest do
      params_hash = { articles: [{ id: @bot_responses.suggested_articles.keys[0].to_i, agent_feedback: "hello" }] }
      put :update, construct_params(version: 'private', id: @ticket.display_id, bot_response: params_hash)
      assert_response 400
      match_json([bad_request_error_pattern_with_nested_field('articles', 'agent_feedback', :"It should be a/an Boolean", code: :datatype_mismatch)])
    end
  end

  def test_bot_response_update_article_with_agent_feedback_value_true
    enable_agent_articles_suggest do
      params_hash = { articles: [{ id: @bot_responses.suggested_articles.keys[0].to_i, agent_feedback: true }] }
      put :update, construct_params(version: 'private', id: @ticket.display_id, bot_response: params_hash)
      assert_response 200
      match_json(bot_response_pattern(@bot_responses, params_hash))
    end
  end

  def test_bot_response_update_article_with_customer_feedback_and_agent_feedback_value
    enable_agent_articles_suggest do
      params_hash = { articles: [{ id: @bot_responses.suggested_articles.keys[0].to_i, agent_feedback: false }] }
      @bot_responses.assign_useful(@bot_responses.suggested_articles.keys[0].to_i, true)
      @bot_responses.save
      put :update, construct_params(version: 'private', id: @ticket.display_id, bot_response: params_hash)
      assert_response 400
      match_json([bad_request_error_pattern('article', :inaccessible_field)])
    end
  end

  def test_bot_response_update_article_with_invalid_article_id
    enable_agent_articles_suggest do
      params_hash = { articles: [{ id: Faker::Number.number(8).to_i, agent_feedback: true }] }
      put :update, construct_params(version: 'private', id: @ticket.display_id, bot_response: params_hash)
      assert_response 400
      match_json([bad_request_error_pattern_with_nested_field('articles', 'id', :not_included, list: @bot_responses.suggested_articles.keys.join(','))])
    end
  end
  
  ###############BOT AGENT RESPONSE##############
  def test_bot_response_update_for_bot_agent_response_feature
    enable_agent_articles_suggest do
      params_hash = { articles: [{ id: @bot_responses.suggested_articles.keys[0].to_i, agent_feedback: false }] }
      put :update, construct_params(version: 'private', id: @ticket.display_id, bot_response: params_hash)
      assert_response 200
      match_json(bot_response_pattern(@bot_responses, params_hash))
    end
  end

  def test_for_bot_agent_response_feature_response_update_empty
    enable_agent_articles_suggest do
      params_hash = {}
      put :update, construct_params(version: 'private', id: @ticket.display_id, bot_response: params_hash)
      assert_response 400
      match_json(request_error_pattern(:missing_params))
    end
  end

  def test_bot_response_update_invalid_key_for_bot_agent_response_feature
    enable_agent_articles_suggest do
      params_hash = { article: [{ id: @bot_responses.suggested_articles.keys[0].to_i, agent_feedback: false }] }
      put :update, construct_params(version: 'private', id: @ticket.display_id, bot_response: params_hash)
      assert_response 400
      match_json([bad_request_error_pattern('article', :invalid_field)])
    end
  end

  def test_bot_response_update_empty_value_for_bot_agent_response_feature
    enable_agent_articles_suggest do
      params_hash = { articles: [] }
      put :update, construct_params(version: 'private', id: @ticket.display_id, bot_response: params_hash)
      assert_response 400
      match_json([bad_request_error_pattern('articles', :"can't be blank", code: :invalid_value)])
    end
  end

  def test_bot_response_update_invalid_article_keys_for_bot_agent_response_feature
    enable_agent_articles_suggest do
      params_hash = { articles: [{ id: @bot_responses.suggested_articles.keys[0].to_i, agent_feedbacks: false }, 
        { ids: @bot_responses.suggested_articles.keys[1].to_i, agent_feedback: false }] }
      put :update, construct_params(version: 'private', id: @ticket.display_id, bot_response: params_hash)
      assert_response 400
      match_json([bad_request_error_pattern('articles[0][agent_feedback]', :missing_field),
        bad_request_error_pattern('articles[0][agent_feedbacks]', :invalid_field),
        bad_request_error_pattern('articles[1][id]', :missing_field),
        bad_request_error_pattern('articles[1][ids]', :invalid_field)])
    end
  end

  def test_bot_response_update_article_with_invalid_id_datatype_for_bot_agent_response_feature
    enable_agent_articles_suggest do
      params_hash = { articles: [{ id: @bot_responses.suggested_articles.keys[0].to_s, agent_feedback: false }] }
      put :update, construct_params(version: 'private', id: @ticket.display_id, bot_response: params_hash)
      assert_response 400
      match_json([bad_request_error_pattern_with_nested_field('articles', 'id', :"It should be a/an Positive Integer", code: :datatype_mismatch)])
    end
  end

  def test_bot_response_update_article_with_invalid_agent_feedback_datatype_for_bot_agent_response_feature
    enable_agent_articles_suggest do
      params_hash = { articles: [{ id: @bot_responses.suggested_articles.keys[0].to_i, agent_feedback: "hello" }] }
      put :update, construct_params(version: 'private', id: @ticket.display_id, bot_response: params_hash)
      assert_response 400
      match_json([bad_request_error_pattern_with_nested_field('articles', 'agent_feedback', :"It should be a/an Boolean", code: :datatype_mismatch)])
    end
  end

  def test_bot_response_update_article_with_customer_feedback_and_agent_feedback_value_for_bot_agent_response_feature
    enable_agent_articles_suggest do
      params_hash = { articles: [{ id: @bot_responses.suggested_articles.keys[0].to_i, agent_feedback: false }] }
      @bot_responses.assign_useful(@bot_responses.suggested_articles.keys[0].to_i, true)
      @bot_responses.save
      put :update, construct_params(version: 'private', id: @ticket.display_id, bot_response: params_hash)
      assert_response 400
      match_json([bad_request_error_pattern('article', :inaccessible_field)])
    end
  end

  def test_bot_response_update_article_with_invalid_article_id_for_bot_agent_response_feature
    enable_agent_articles_suggest do
      params_hash = { articles: [{ id: Faker::Number.number(8).to_i, agent_feedback: true }] }
      put :update, construct_params(version: 'private', id: @ticket.display_id, bot_response: params_hash)
      assert_response 400
      match_json([bad_request_error_pattern_with_nested_field('articles', 'id', :not_included, list: @bot_responses.suggested_articles.keys.join(','))])
    end
  end

  def test_bot_update_without_feature_for_bot_email_channel_and_bot_agent_response
    params_hash = { articles: [{ id: @bot_responses.suggested_articles.keys[0].to_i, agent_feedback: false }] }
    put :update, construct_params(version: 'private', id: @ticket.display_id, bot_response: params_hash)
    assert_response 403
  end
  ###############SHOW BOT RESPONSE##############

  ###############BOT EMAIL CHANNEL################ 
  def test_bot_response_show
    enable_agent_articles_suggest do
      get :show, construct_params(version: 'private', id: @ticket.display_id)
      assert_response 200
      match_json(bot_response_pattern(@bot_responses))
    end
  end

  def test_bot_response_show_with_empty
    enable_agent_articles_suggest do
      @bot_responses.destroy
      get :show, construct_params(version: 'private', id: @ticket.display_id)
      assert_response 204
    end
  end

  def test_bot_response_show_with_invalid_ticket_id
    enable_agent_articles_suggest do
      get :show, construct_params(version: 'private', id: 0)
      assert_response 404
    end
  end

  ###############BOT AGENT RESPONSE##############
  def test_bot_response_show_with_feature_bot_agent_response
    enable_agent_articles_suggest do
      get :show, construct_params(version: 'private', id: @ticket.display_id)
      assert_response 200
      match_json(bot_response_pattern(@bot_responses))
    end
  end

  def test_bot_response_show_with_empty_for_feature_bot_agent_response
    enable_agent_articles_suggest do
      @bot_responses.destroy
      get :show, construct_params(version: 'private', id: @ticket.display_id)
      assert_response 204
    end
  end

  def test_bot_response_show_with_invalid_ticket_id_for_feature_bot_agent_response
    enable_agent_articles_suggest do
      get :show, construct_params(version: 'private', id: 0)
      assert_response 404
    end
  end

  def test_bot_response_show_without_feature
    get :show, construct_params(version: 'private', id: @ticket.display_id)
    assert_response 403
  end


  def test_create_response_check_bot_type
    enable_bot do
      ticket = create_ticket
      bot_responses = create_bot_response(ticket.id, @bot.id)
      assert_equal bot_responses.bot.external_id, @bot.external_id
    end
  end
end