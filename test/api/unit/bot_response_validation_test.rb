require_relative '../unit_test_helper'

class BotResponseValidationTest < ActionView::TestCase
  def test_bot_response_validation_valid_param
    Account.stubs(:current).returns(Account.new)
    article_id = Faker::Number.number(4).to_i
    params_hash = { articles: [{ id: article_id, agent_feedback: false }], suggested_articles: { article_id => {} } }
    bot_response_validation = BotResponseValidation.new(params_hash)
    assert bot_response_validation.valid?
  end

  def test_bot_response_validation_with_empty_value
    params_hash = { articles: [] }
    bot_response_validation =  BotResponseValidation.new(params_hash)
    refute bot_response_validation.valid?
    errors = bot_response_validation.errors.full_messages
    assert errors.include?("Articles can't be blank")
  end

  def test_bot_response_validation_invalid_article_keys
    article_id_1 = Faker::Number.number(4).to_i
    article_id_2 = Faker::Number.number(4).to_i
    params_hash = { articles: [{ id: article_id_1, agent_feedbacks: false }, 
        { ids: article_id_2, agent_feedback: false }], suggested_articles: { article_id_1 => {}, article_id_2 => {} } }
    bot_response_validation =  BotResponseValidation.new(params_hash)
    refute bot_response_validation.valid?
    errors = bot_response_validation.errors.full_messages
    assert errors.include?("Articles[0][agent feedback] missing_field")
    assert errors.include?("Articles[0][agent feedbacks] invalid_field")
    assert errors.include?("Articles[1][id] missing_field")
    assert errors.include?("Articles[1][ids] invalid_field")
  end

  def test_bot_response_validation_article_with_invalid_id_datatype
    article_id = Faker::Number.number(4).to_i
    params_hash = { articles: [{ id: article_id.to_s, agent_feedback: false }], suggested_articles: { article_id => {} } }
    bot_response_validation =  BotResponseValidation.new(params_hash)
    refute bot_response_validation.valid?
    errors = bot_response_validation.errors.full_messages
    assert errors.include?("Articles datatype_mismatch")
  end

  def test_bot_response_validation_article_with_invalid_agent_feedback_datatype
    article_id = Faker::Number.number(4).to_i
    params_hash = { articles: [{ id: article_id, agent_feedback: "hello" }], suggested_articles: { article_id => {} } }
    bot_response_validation =  BotResponseValidation.new(params_hash)
    refute bot_response_validation.valid?
    errors = bot_response_validation.errors.full_messages
    assert errors.include?("Articles datatype_mismatch")
  end

  def test_bot_response_validation_with_agent_feedback_value_true
    article_id = Faker::Number.number(4).to_i
    params_hash = { articles: [{ id: article_id, agent_feedback: true }], suggested_articles: { article_id => {} } }
    bot_response_validation =  BotResponseValidation.new(params_hash)
    assert bot_response_validation.valid?
  end

  def test_bot_response_validation_with_customer_feedback_and_agent_feedback_value
    article_id = Faker::Number.number(4).to_i
    params_hash = { articles: [{ id: article_id, agent_feedback: false }], suggested_articles: { article_id => { useful: false} } }
    bot_response_validation =  BotResponseValidation.new(params_hash)
    refute bot_response_validation.valid?
    errors = bot_response_validation.errors.full_messages
    assert errors.include?("Article inaccessible_field")
  end

  def test_bot_response_validation_with_invalid_article_id
    params_hash = { articles: [{ id: Faker::Number.number(4).to_i, agent_feedback: true }], suggested_articles: { Faker::Number.number(4).to_i => {} } }
    bot_response_validation =  BotResponseValidation.new(params_hash)
    refute bot_response_validation.valid?
    errors = bot_response_validation.errors.full_messages
    assert errors.include?("Articles not_included")
  end
end