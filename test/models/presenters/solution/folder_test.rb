require_relative '../../test_helper'

class FolderTest < ActiveSupport::TestCase
  include ModelsSolutionsTestHelper

  def test_central_publish_payload
    folder = create_folder.primary_folder
    payload = folder.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_folder_pattern(folder))
  end

  def test_ml_training_payload
    folder = create_folder.primary_folder
    folder.central_payload_type = :ml_training
    payload = folder.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_folder_pattern(folder))
  end

  def test_central_publish_destroy_payload
    folder = create_folder.primary_folder
    CentralPublisher::Worker.jobs.clear
    folder.destroy
    job = CentralPublisher::Worker.jobs.last
    assert_equal CentralPublisher::Worker.jobs.size, 1
    assert_equal 'folder_destroy', job['args'][0]
    assert_equal({}, job['args'][1]['model_changes'])
    job['args'][1]['model_properties'].must_match_json_expression(central_publish_folder_destroy_pattern(folder))
  end

  def test_central_publish_payload_update_category
    folder = create_folder.primary_folder
    old_category = @account.solution_categories.where(parent_id: folder.parent.solution_category_meta_id, language_id: folder.language_id).first
    new_category = create_category(category_params)
    CentralPublisher::Worker.jobs.clear
    folder.parent.solution_category_meta_id = new_category.id
    folder.parent.save
    folder.save
    payload = folder.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_folder_pattern(folder))
    job = CentralPublisher::Worker.jobs.last
    assert_equal 'folder_update', job['args'][0]
    assert_equal CentralPublisher::Worker.jobs.size, 1
    assert_equal({ 'solution_category_name' => [old_category.name, new_category.name] }, job['args'][1]['misc_changes'].slice('solution_category_name'))
  end

  def category_params(options = {})
    lang_hash = { lang_codes: options[:lang_codes] }
    { portal_id: Account.current.main_portal.id }.merge(lang_hash)
  end
end
