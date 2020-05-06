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
    Account.any_instance.stubs(:solutions_central_publish_enabled?).returns(true)
    folder = create_folder.primary_folder
    CentralPublisher::Worker.jobs.clear
    folder.destroy
    job = CentralPublisher::Worker.jobs.last
    assert_equal CentralPublisher::Worker.jobs.size, 1
    assert_equal 'folder_destroy', job['args'][0]
    assert_equal({}, job['args'][1]['model_changes'])
    job['args'][1]['model_properties'].must_match_json_expression(central_publish_folder_destroy_pattern(folder))
  ensure
    Account.any_instance.unstub(:solutions_central_publish_enabled?)
  end
end
