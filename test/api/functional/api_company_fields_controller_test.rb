require_relative '../test_helper'
class ApiCompanyFieldsControllerTest < ActionController::TestCase
  include Helpers::CompaniesTestHelper
  def wrap_cname(params)
    { api_company_field: params }
  end

  def test_index
    get :index, controller_params
    pattern = []
    Account.current.company_form.company_fields.each do |cf|
      pattern << company_field_pattern(CompanyField.find(cf.id))
    end
    assert_response 200
    match_json(pattern.ordered!)
  end

   def test_index_with_pagination
    get :index, controller_params(per_page: 1)
    assert_response 200
    assert JSON.parse(response.body).count == 1
    get :index, controller_params(per_page: 1, page: 2)
    assert_response 200
    assert JSON.parse(response.body).count == 1
  end

  def test_index_with_pagination_exceeds_limit
    get :index, controller_params(per_page: 101)
    assert_response 400
    match_json([bad_request_error_pattern('per_page', :gt_zero_lt_max_per_page, data_type: 'Positive Integer')])
  end
end
