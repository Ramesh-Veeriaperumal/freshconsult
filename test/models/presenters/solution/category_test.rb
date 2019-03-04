require_relative '../../test_helper'

class CategoryTest < ActiveSupport::TestCase
  include ModelsSolutionsTestHelper

  def test_central_publish_payload
    category = add_new_category
    payload = category.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_category_pattern(category))
  end

  def test_ml_training_payload
    category = add_new_category
    category.central_payload_type = :ml_training
    payload = category.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_category_pattern(category))
  end
end
