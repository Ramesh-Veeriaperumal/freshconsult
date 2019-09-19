require_relative '../../api/test_helper'
require_relative '../../core/helpers/controller_test_helper'

class HomeControllerTest < ActionController::TestCase
#   include CoreUsersTestHelper
  include ControllerTestHelper
    def setup
        super
      end
    
    def test_mobile_app_onboarding_calls
        login_admin
        @request.env['HTTP_USER_AGENT'] = 'Android'
        # @mobile_user_agent = true
        @request['HTTP_COOKIE'] = { 'skip_mobile_app_download' => false }
        
        get :index 
        assert_response 302
        assert_location
    end

    def test_mobile_app_onboarding_calls_for_ios
        @request.env['HTTP_USER_AGENT'] = 'ios'

    end

    def test_mobile_app_onboarding_calls_for_desktop
        @request.env['HTTP_USER_AGENT'] = 'Chrome/75.0.3770.142'
    end

end