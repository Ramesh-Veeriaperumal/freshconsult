require_relative '../../test_helper'
require Rails.root.join('spec', 'support', 'solutions_helper.rb')
require Rails.root.join('test', 'api', 'helpers', 'jwt_test_helper.rb')
require Rails.root.join('test', 'api', 'helpers', 'portals_customisation_test_helper.rb')

module Channel
  class PortalsControllerTest < ActionController::TestCase
    include SolutionsHelper
    include JweTestHelper
    include PortalsCustomisationTestHelper

    def setup
      super
      before_all
    end

    def wrap_cname(params)
      { portal: params }
    end

    @before_all_run = false

    def before_all
      return if @before_all_run

      3.times do
        create_portal
      end
      @before_all_run = true
    end

    def test_index
      set_jwt_auth_header('field_service')
      get :index, controller_params(version: 'channel')
      pattern = []
      Account.current.portals.all.each do |portal|
        pattern << portal_pattern(portal)
      end
      assert_response 200
      match_json(pattern.ordered!)
    end

    def test_index_without_jwt_token
      get :index, controller_params(version: 'channel')
      assert_response 401
      match_json(request_error_pattern(:invalid_credentials))
    end
  end
end
