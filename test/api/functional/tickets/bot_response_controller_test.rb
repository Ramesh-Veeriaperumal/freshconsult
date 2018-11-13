require_relative '../../test_helper'

class Tickets::BotResponseControllerTest < ActionController::TestCase
  include TicketsTestHelper
  include BotTestHelper
  include BotResponseTestHelper

  def setup
    super
    @ticket = create_ticket
    @bot = create_bot({ product: true})
    @bot_responses = create_bot_response(@ticket.id, @bot.id)
  end

  def teardown
    @ticket.destroy
    @bot.destroy
  end

  ###############UPDATE BOT RESPONSE##############
  def test_bot_response_update
    enable_bot_email_channel do
      params_hash = { articles: [{ id: @bot_responses.suggested_articles.keys[0].to_i, agent_feedback: false }] }
      put :update, construct_params(version: 'private', id: @ticket.display_id, bot_response: params_hash)
      assert_response 200
      match_json(bot_response_pattern(@bot_responses, params_hash))
    end
  end

  def test_bot_update_without_feature
    params_hash = { articles: [{ id: @bot_responses.suggested_articles.keys[0].to_i, agent_feedback: false }] }
    put :update, construct_params(version: 'private', id: @ticket.display_id, bot_response: params_hash)
    assert_response 403
    match_json(request_error_pattern(:require_feature, feature: :"Bot Email Channel"))
  end

  def test_bot_response_update_empty
    enable_bot_email_channel do
      params_hash = {}
      put :update, construct_params(version: 'private', id: @ticket.display_id, bot_response: params_hash)
      assert_response 400
      match_json(request_error_pattern(:missing_params))
    end
  end

  def test_bot_response_update_invalid_key
    enable_bot_email_channel do
      params_hash = { article: [{ id: @bot_responses.suggested_articles.keys[0].to_i, agent_feedback: false }] }
      put :update, construct_params(version: 'private', id: @ticket.display_id, bot_response: params_hash)
      assert_response 400
      match_json([bad_request_error_pattern('article', :invalid_field)])
    end
  end

  def test_bot_response_update_empty_value
    enable_bot_email_channel do
      params_hash = { articles: [] }
      put :update, construct_params(version: 'private', id: @ticket.display_id, bot_response: params_hash)
      assert_response 400
      match_json([bad_request_error_pattern('articles', :"can't be blank", code: :invalid_value)])
    end
  end

  def test_bot_response_update_invalid_article_keys
    enable_bot_email_channel do
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
    enable_bot_email_channel do
      params_hash = { articles: [{ id: @bot_responses.suggested_articles.keys[0].to_s, agent_feedback: false }] }
      put :update, construct_params(version: 'private', id: @ticket.display_id, bot_response: params_hash)
      assert_response 400
      match_json([bad_request_error_pattern_with_nested_field('articles', 'id', :"It should be a/an Positive Integer", code: :datatype_mismatch)])
    end
  end


  def test_bot_response_update_article_with_invalid_agent_feedback_datatype
    enable_bot_email_channel do
      params_hash = { articles: [{ id: @bot_responses.suggested_articles.keys[0].to_i, agent_feedback: "hello" }] }
      put :update, construct_params(version: 'private', id: @ticket.display_id, bot_response: params_hash)
      assert_response 400
      match_json([bad_request_error_pattern_with_nested_field('articles', 'agent_feedback', :"It should be a/an Boolean", code: :datatype_mismatch)])
    end
  end

  def test_bot_response_update_article_with_invalid_agent_feedback_value
    enable_bot_email_channel do
      params_hash = { articles: [{ id: @bot_responses.suggested_articles.keys[0].to_i, agent_feedback: true }] }
      put :update, construct_params(version: 'private', id: @ticket.display_id, bot_response: params_hash)
      assert_response 400
      match_json([bad_request_error_pattern_with_nested_field('articles', 'agent_feedback', :not_included, list: ['false'])])
    end
  end

  def test_bot_response_update_article_with_customer_feedback_and_agent_feedback_value
    enable_bot_email_channel do
      params_hash = { articles: [{ id: @bot_responses.suggested_articles.keys[0].to_i, agent_feedback: false }] }
      @bot_responses.assign_useful(@bot_responses.suggested_articles.keys[0].to_i, true)
      @bot_responses.save
      put :update, construct_params(version: 'private', id: @ticket.display_id, bot_response: params_hash)
      assert_response 400
      match_json([bad_request_error_pattern('article', :inaccessible_field)])
    end
  end

  def test_bot_response_update_article_with_invalid_article_id
    enable_bot_email_channel do
      params_hash = { articles: [{ id: Faker::Number.number(8).to_i, agent_feedback: true }] }
      put :update, construct_params(version: 'private', id: @ticket.display_id, bot_response: params_hash)
      assert_response 400
      match_json([bad_request_error_pattern_with_nested_field('articles', 'id', :not_included, list: @bot_responses.suggested_articles.keys.join(','))])
    end
  end

  ###############SHOW BOT RESPONSE##############
  def test_bot_response_show
    enable_bot_email_channel do
      get :show, construct_params(version: 'private', id: @ticket.display_id)
      assert_response 200
      match_json(bot_response_pattern(@bot_responses))
    end
  end

  def test_bot_response_show_with_empty
    enable_bot_email_channel do
      @bot_responses.destroy
      get :show, construct_params(version: 'private', id: @ticket.display_id)
      assert_response 204
    end
  end

  def test_bot_response_show_with_invalid_ticket_id
    enable_bot_email_channel do
      get :show, construct_params(version: 'private', id: 0)
      assert_response 404
    end
  end

  def test_bot_response_show_without_feature
    get :show, construct_params(version: 'private', id: @ticket.display_id)
    assert_response 403
    match_json(request_error_pattern(:require_feature, feature: :"Bot Email Channel"))
  end
end