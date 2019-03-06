require_relative '../../test_helper'

class FolderTest < ActiveSupport::TestCase
  include ModelsSolutionsTestHelper

  def test_central_publish_payload
    folder = add_new_folder
    payload = folder.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_folder_pattern(folder))
  end

  def test_ml_training_payload
    folder = add_new_folder
    folder.central_payload_type = :ml_training
    payload = folder.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_folder_pattern(folder))
  end
end
