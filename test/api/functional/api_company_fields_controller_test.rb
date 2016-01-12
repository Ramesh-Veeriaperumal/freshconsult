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

  def test_index_ignores_pagination
    get :index, controller_params(per_page: 1, page: 2)
    assert_response 200
    assert JSON.parse(response.body).count > 1
  end
end
