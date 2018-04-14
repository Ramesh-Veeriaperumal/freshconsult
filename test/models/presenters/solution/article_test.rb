require_relative '../../test_helper'

class ArticleTest < ActiveSupport::TestCase
  include SolutionsTestHelper

  def test_central_publish_payload
    article = add_new_article
    payload = article.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_article_pattern(article))
  end

  def test_votes_payload
    article = add_new_article
    article.central_payload_type = :article_thumbs_up
    payload = article.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_article_votes_pattern(article))
  end

  def test_ml_training_payload
    article = add_new_article
    article.central_payload_type = :ml_training
    payload = article.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_article_pattern(article))
  end
end
