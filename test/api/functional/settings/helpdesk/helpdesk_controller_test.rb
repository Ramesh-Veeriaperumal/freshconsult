require_relative '../../../test_helper'
module Settings
	class HelpdeskControllerTest < ActionController::TestCase
	  include HelpdeskTestHelper
	  def test_helpdesk_index
	    get :index, controller_params
	    assert_response 200
	    match_json(helpdesk_languages_pattern(@account))
	  end
	end
end
