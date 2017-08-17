require_relative '../../test_helper'
class Ember::CloudFilesControllerTest < ActionController::TestCase

	def setup
    super
    Integrations::InstalledApplication.any_instance.stubs(:marketplace_enabled?).returns(false)
    @api_params = { version: 'private' }
  end

  def teardown
    super
    Integrations::InstalledApplication.unstub(:marketplace_enabled?)
  end

	def test_delete_with_invalid_id
	  delete :destroy, construct_params(@api_params, false).merge(id: 100)
	  assert_response 404
	end
	
end