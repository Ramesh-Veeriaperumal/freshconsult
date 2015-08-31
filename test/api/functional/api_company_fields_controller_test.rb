require_relative '../test_helper'
class ApiCompanyFieldsControllerTest < ActionController::TestCase
  def wrap_cname(params)
    { api_company_field: params }
  end

  def test_index
    get :index, request_params
    pattern = []
    Account.current.company_form.company_fields.each do |cf|
      pattern << company_field_pattern(CompanyField.find(cf.id))
    end
    assert_response :success
    match_json(pattern)
  end
end
