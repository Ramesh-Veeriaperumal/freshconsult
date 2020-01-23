require_relative '../../test_helper'

class CategoryTest < ActiveSupport::TestCase
  include ModelsSolutionsTestHelper

  def test_central_publish_payload
    category = add_new_category
    payload = JSON.parse(category.central_publish_payload.to_json).except!('created_at', 'updated_at')
    expected_payload = central_publish_category_pattern(category).except!(:created_at, :updated_at)
    payload.must_match_json_expression(expected_payload)
  end

  def test_ml_training_payload
    category = add_new_category
    payload = JSON.parse(category.central_publish_payload.to_json).except!('created_at', 'updated_at')
    expected_payload = central_publish_category_pattern(category).except!(:created_at, :updated_at)
    payload.must_match_json_expression(expected_payload)
  end
end
