require_relative '../test_helper'
class ApiCompanyFieldsControllerTest < ActionController::TestCase
  include CompaniesTestHelper
  def wrap_cname(params)
    { api_company_field: params }
  end

  def test_index_with_privilege
    User.any_instance.stubs(:privilege?).with(:manage_companies).returns(true).at_most_once
    get :index, controller_params
    assert_response 200
    assert JSON.parse(response.body).count > 1
  ensure
    User.any_instance.unstub(:privilege?)
  end

  def test_index_without_privilege
    User.any_instance.stubs(:privilege?).with(:manage_companies).returns(false).at_most_once
    User.any_instance.stubs(:privilege?).with(:admin_tasks).returns(false).at_most_once
    get :index, controller_params
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  ensure
    User.any_instance.unstub(:privilege?)
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

  def test_company_field_index_with_custom_field_name_same_as_default_field_name
    Account.any_instance.stubs(:handle_custom_fields_conflicts_enabled?).returns(true)
    create_company_field(company_params(type: 'text', field_type: 'custom_text', label: 'Name', editable_in_signup: 'true'))
    create_company_field(company_params(type: 'boolean', field_type: 'custom_checkbox', label: 'Domains', editable_in_signup: 'true'))
    create_company_field(company_params(type: 'date', field_type: 'custom_date', label: 'Description', editable_in_signup: 'true'))
    create_company_field(company_params(type: 'text', field_type: 'custom_dropdown', label: 'Health Score', editable_in_signup: 'true'))
    CompanyFieldChoice.create(value: 'At Risk', position: 1)
    CompanyFieldChoice.create(value: 'Doing Okay', position: 2)
    CompanyFieldChoice.create(value: 'Happy', position: 3)
    CompanyFieldChoice.update_all(account_id: @account.id)
    CompanyFieldChoice.update_all(company_field_id: CompanyField.where(name: 'cf_custom_health_score').first.id)
    @account.reload

    company_custom_fields = @account.company_form.custom_fields
    assert_equal company_custom_fields.where(label: 'Name').first.name, 'cf_custom_name'
    assert_equal company_custom_fields.where(label: 'Domains').first.name, 'cf_custom_domains'
    assert_equal company_custom_fields.where(label: 'Description').first.name, 'cf_custom_description'
    assert_equal company_custom_fields.where(label: 'Health Score').first.name, 'cf_custom_health_score'

    get :index, controller_params
    assert_response 200
    company_fields = @account.reload.company_form.company_fields
    pattern = company_fields.map { |company_field| company_field_pattern(company_field) }
    match_json(pattern)
  ensure
    Account.any_instance.unstub(:handle_custom_fields_conflicts_enabled?)
  end

  def test_index_ignores_pagination
    get :index, controller_params(per_page: 1, page: 2)
    assert_response 200
    assert JSON.parse(response.body).count > 1
  end
end
