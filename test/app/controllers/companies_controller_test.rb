# frozen_string_literal: true

require_relative '../../api/test_helper.rb'
require_relative '../../core/helpers/controller_test_helper'
require_relative '../../api/helpers/search_test_helper'

class CompaniesControllerTest < ActionController::TestCase
  include ControllerTestHelper
  include SearchTestHelper

  def test_es_filter_search_company_name_with_exact_match_results
    login_admin

    company = create_company(name: 'Company Inc.')

    stub_private_search_response([company]) do
      get :index, company: {}, format: 'json', letter: 'Company Inc.'
    end
    assert_response 200
    assert JSON.parse(response.body).count == 1

    log_out
  end
end
