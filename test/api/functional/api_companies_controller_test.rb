require_relative '../test_helper'
class ApiCompaniesControllerTest < ActionController::TestCase
  def wrap_cname(params)
    { api_company: params }
  end

  def setup
    super
    custom_field_params.each do |field| # to create company custom fields
      params = company_params(field)
      create_company_field params
    end
    clear_contact_field_cache
  end

  def teardown
    super
    destroy_custom_fields
  end

  def domain_array
    [Faker::Lorem.characters(6), Faker::Lorem.characters(5)]
  end

  def test_create_company
    post :create, construct_params({}, name: Faker::Lorem.characters(10), description: Faker::Lorem.paragraph,
                                       domains: domain_array, note: Faker::Lorem.characters(10))
    assert_response :created
    match_json(company_pattern(Company.last))
  end

  def test_create_company_with_custom_fields
    post :create, construct_params({}, name: Faker::Lorem.characters(10), description: Faker::Lorem.paragraph,
                                       domains: domain_array, note: Faker::Lorem.characters(10),
                                       custom_fields: { 'cf_linetext' => 'test123' })
    assert_response :created
    match_json(company_pattern(Company.last))
  end

  def test_create_company_quick
    post :create, construct_params({}, name: Faker::Lorem.characters(10))
    assert_response :created
    match_json(company_pattern(Company.last))
  end

  def test_create_company_without_name
    post :create, construct_params({}, description: Faker::Lorem.paragraph,
                                       domains: domain_array)
    assert_response :bad_request
    match_json([bad_request_error_pattern('name', 'missing_field')])
  end

  def test_create_company_with_wrong_format
    post :create, construct_params({}, name: Faker::Number.number(10).to_i, description: Faker::Number.number(10).to_i,
                                       domains: domain_array)
    assert_response :bad_request
    match_json([bad_request_error_pattern('name', 'data_type_mismatch', data_type: 'String'),
                bad_request_error_pattern('description', 'data_type_mismatch', data_type: 'String')])
  end

  def test_create_company_with_invalid_custom_fields
    post :create, construct_params({}, name: Faker::Lorem.characters(10), description: Faker::Lorem.paragraph,
                                       domains: domain_array, note: Faker::Lorem.characters(10),
                                       custom_fields: { 'cf_invalid' => Faker::Lorem.characters(10) })
    assert_response :bad_request
    match_json([bad_request_error_pattern('cf_invalid', 'invalid_field')])
  end

  def test_update_company
    company = create_company(name: Faker::Lorem.characters(10), description: Faker::Lorem.paragraph)
    name = Faker::Lorem.characters(10)
    put :update, construct_params({ id: company.id }, name: name, description: Faker::Lorem.paragraph,
                                                      note: Faker::Lorem.characters(5), domains: domain_array,
                                                      custom_fields: { 'cf_linetext' => Faker::Lorem.characters(10) })
    assert_response :success
    match_json(company_pattern({ name => name }, company.reload))
  end

  def test_update_company_with_blank_name
    company = create_company(name: Faker::Lorem.characters(10), description: Faker::Lorem.paragraph)
    put :update, construct_params({ id: company.id }, name: '', description: Faker::Lorem.paragraph,
                                                      note: Faker::Lorem.characters(10), domains: domain_array,
                                                      custom_fields: { 'cf_linetext' => Faker::Lorem.characters(10) })
    assert_response :bad_request
    match_json([bad_request_error_pattern('name', "can't be blank")])
  end

  def test_update_company_with_invalid_id
    put :update, construct_params({ id: Faker::Number.number(7).to_i }, name: Faker::Lorem.characters(10), description: Faker::Lorem.paragraph,
                                                                        note: Faker::Lorem.characters(10), domains: domain_array,
                                                                        custom_fields: { 'cf_linetext' => Faker::Lorem.characters(10) })
    assert_equal ' ', @response.body
    assert_response :missing
  end

  def test_update_company_with_invalid_fields
    company = create_company(name: Faker::Lorem.characters(10), description: Faker::Lorem.paragraph)
    put :update, construct_params({ id:  company.id }, name: Faker::Number.number(10).to_i, description: Faker::Number.number(10).to_i,
                                                       domains: domain_array)
    assert_response :bad_request
    match_json([bad_request_error_pattern('name', 'data_type_mismatch', data_type: 'String'),
                bad_request_error_pattern('description', 'data_type_mismatch', data_type: 'String')])
  end

  def test_update_company_with_invalid_custom_field
    company = create_company(name: Faker::Lorem.characters(10), description: Faker::Lorem.paragraph)
    put :update, construct_params({ id: company.id }, name: Faker::Lorem.characters(10),
                                                      note: Faker::Lorem.characters(10), domains: domain_array,
                                                      custom_fields: { 'cf_invalid' => Faker::Lorem.characters(10) })
    assert_response :bad_request
    match_json([bad_request_error_pattern('cf_invalid', 'invalid_field')])
  end

  def test_delete_company
    company = create_company
    delete :destroy, construct_params(id: company.id)
    assert_equal ' ', 	@response.body
    assert_nil Company.find_by_id(company.id)
  end

  def test_index_companies
    get :index, request_params
    assert_equal Company.all, assigns(:items).sort
  end

  def test_show_company
    company = create_company
    get :show, construct_params(id: company.id)
    assert_response :success
    match_json(company_pattern(Company.find(company.id)))
  end

  def test_handle_show_request_for_missing_company
    get :show, construct_params(id: 2000)
    assert_response :missing
    assert_equal ' ', response.body
  end

  def test_handle_show_request_for_invalid_company_id
    get :show, construct_params(id: Faker::Name.name)
    assert_response :missing
    assert_equal ' ', response.body
  end

  def test_index
    get :index, request_params
    pattern = []
    Account.current.companies.all.each do |company|
      pattern << company_pattern(Company.find(company.id))
    end
    assert_response :success
    match_json(pattern)
  end

  def test_company_with_pagination_enabled
    3.times do
      create_company
    end
    get :index, construct_params(per_page: 1)
    assert_response :success
    assert JSON.parse(response.body).count == 1
    get :index, construct_params(per_page: 1, page: 2)
    assert_response :success
    assert JSON.parse(response.body).count == 1
    get :index, construct_params(per_page: 1, page: 3)
    assert_response :success
    assert JSON.parse(response.body).count == 1
  end

  def test_company_with_pagination_exceeds_limit
    ApiConstants::DEFAULT_PAGINATE_OPTIONS.stubs(:[]).with(:per_page).returns(2)
    ApiConstants::DEFAULT_PAGINATE_OPTIONS.stubs(:[]).with(:max_per_page).returns(3)
    ApiConstants::DEFAULT_PAGINATE_OPTIONS.stubs(:[]).with(:page).returns(1)
    get :index, construct_params(per_page: 4)
    assert_response :success
    assert JSON.parse(response.body).count == 3
    ApiConstants::DEFAULT_PAGINATE_OPTIONS.unstub(:[])
  end

  def test_create_companies_with_invalid_domains
    post :create, construct_params({}, name: Faker::Lorem.characters(10), description: Faker::Lorem.paragraph,
                                       domains: Faker::Lorem.characters(10).to_i, note: Faker::Lorem.characters(10))
    assert_response :bad_request
    match_json([bad_request_error_pattern('domains', 'data_type_mismatch', data_type: 'Array')])
  end

  def test_create_companies_with_empty_domains
    post :create, construct_params({}, name: Faker::Lorem.characters(10), description: Faker::Lorem.paragraph,
                                       domains: [], note: Faker::Lorem.characters(10))
    assert_response :created
    match_json(company_pattern(Company.last))
  end

  def test_update_companies_with_invalid_domains_value
    post :create, construct_params({}, name: Faker::Lorem.characters(10), description: Faker::Lorem.paragraph,
                                       domains: [Faker::Lorem.characters(10).to_i, Faker::Lorem.characters(10)], note: Faker::Lorem.characters(10))
    assert_response :bad_request
    match_json([bad_request_error_pattern('domains', 'data_type_mismatch', data_type: 'String')])
  end

  def test_create_company_with_invalid_customer_field_values
    post :create, construct_params({}, name: Faker::Lorem.characters(10), description: Faker::Lorem.paragraph,
                                       domains: domain_array, note: Faker::Lorem.characters(10),
                                       custom_fields: { 'cf_linetext' => 'test123', 'cf_testimony' => 123,
                                                        'cf_agt_count' => '67', 'cf_date' => Faker::Lorem.characters(10),
                                                        'cf_show_all_ticket' => Faker::Number.number(5) })
    assert_response :created
  end

  def clear_contact_field_cache
    key = MemcacheKeys::COMPANY_FORM_FIELDS % { account_id: @account.id, company_form_id: @account.company_form.id }
    MemcacheKeys.delete_from_cache key
  end

  def create_company(options = {})
    company = @account.companies.find_by_name(options[:name])
    return company if company
    name = options[:name] || Faker::Name.name
    company = FactoryGirl.build(:company, name: name)
    company.account_id = @account.id
    company.save!
    company
  end
end
