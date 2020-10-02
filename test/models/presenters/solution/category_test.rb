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

  def test_central_publish_destroy_payload
    category = add_new_category
    CentralPublisher::Worker.jobs.clear
    category.destroy
    job = CentralPublisher::Worker.jobs.last
    assert_equal CentralPublisher::Worker.jobs.size, 1
    assert_equal 'category_destroy', job['args'][0]
    assert_equal({}, job['args'][1]['model_changes'])
    job['args'][1]['model_properties'].must_match_json_expression(central_publish_category_destroy_pattern(category))
  end

  def test_central_publish_for_category_update
    category = add_new_category
    CentralPublisher::Worker.jobs.clear
    new_description = Faker::Lorem.sentence(3)
    category.description = new_description
    model_changes = category.changes['description']
    category.save(validate: false)
    job = CentralPublisher::Worker.jobs.last
    assert_equal CentralPublisher::Worker.jobs.size, 1
    assert_equal 'category_update', job['args'][0]
    assert_equal job['args'][1]['model_changes']['description'], model_changes
  end
end
