require_relative '../test_helper'
class ApiCompaniesControllerTest < ActionController::TestCase
  include Helpers::CompaniesTestHelper
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
    assert_response 201
    match_json(company_pattern(Company.last))
  end

  def test_create_company_with_custom_fields
    post :create, construct_params({}, name: Faker::Lorem.characters(10), description: Faker::Lorem.paragraph,
                                       domains: domain_array, note: Faker::Lorem.characters(10),
                                       custom_fields: { 'linetext' => 'test123' })
    assert_response 201
    match_json(company_pattern(Company.last))
  end

  def test_create_company_quick
    post :create, construct_params({}, name: Faker::Lorem.characters(10))
    assert_response 201
    match_json(company_pattern(Company.last))
  end

  def test_create_company_without_name
    post :create, construct_params({}, description: Faker::Lorem.paragraph,
                                       domains: domain_array)
    assert_response 400
    match_json([bad_request_error_pattern('name', :missing_field)])
  end

  def test_create_company_domains_invalid
    post :create, construct_params({}, description: Faker::Lorem.paragraph, name: Faker::Lorem.characters(10),
                                       domains: ['test,,,comma', 'test'])
    assert_response 400
    match_json([bad_request_error_pattern('domains', :special_chars_present, chars: ',')])
  end

  def test_create_company_with_wrong_format
    post :create, construct_params({}, name: Faker::Number.number(10).to_i, description: Faker::Number.number(10).to_i,
                                       domains: domain_array)
    assert_response 400
    match_json([bad_request_error_pattern('name', :data_type_mismatch, data_type: 'String'),
                bad_request_error_pattern('description', :data_type_mismatch, data_type: 'String')])
  end

  def test_create_company_with_invalid_custom_fields
    post :create, construct_params({}, name: Faker::Lorem.characters(10), description: Faker::Lorem.paragraph,
                                       domains: domain_array, note: Faker::Lorem.characters(10),
                                       custom_fields: { 'invalid' => Faker::Lorem.characters(10) })
    assert_response 400
    match_json([bad_request_error_pattern('invalid', :invalid_field)])
  end

  def test_create_company_with_duplicate_name
    name = Faker::Lorem.characters(10)
    company = create_company(name: name, description: Faker::Lorem.paragraph)
    post :create, construct_params({}, name: name, description: Faker::Lorem.paragraph,
                                       domains: domain_array, note: Faker::Lorem.characters(10))
    assert_response 409
    match_json([bad_request_error_pattern('name', :"has already been taken")])
  end

  def test_create_length_invalid
    params_hash = { name: Faker::Lorem.characters(300) }
    post :create, construct_params({}, params_hash)
    match_json([bad_request_error_pattern('name', :"is too long (maximum is 255 characters)")])
    assert_response 400
  end

  def test_create_length_valid_with_trailing_space
    params_hash = { name: Faker::Lorem.characters(20) + white_space }
    post :create, construct_params({}, params_hash)
    assert_response 201
    match_json(company_pattern(Company.last))
  end

  def test_update_company
    company = create_company(name: Faker::Lorem.characters(10), description: Faker::Lorem.paragraph)
    name = Faker::Lorem.characters(10)
    put :update, construct_params({ id: company.id }, name: name, description: Faker::Lorem.paragraph,
                                                      note: Faker::Lorem.characters(5), domains: domain_array,
                                                      custom_fields: { 'linetext' => Faker::Lorem.characters(10) })
    assert_response 200
    match_json(company_pattern({ name => name }, company.reload))
  end

  def test_update_company_with_nil_custom_field
    company = create_company(name: Faker::Lorem.characters(10), description: Faker::Lorem.paragraph)
    put :update, construct_params({ id: company.id }, custom_fields: {})
    match_json(company_pattern({}, company.reload))
    assert_response 200
  end

  def test_update_company_with_custom_field_invalid_format
    company = create_company(name: Faker::Lorem.characters(10), description: Faker::Lorem.paragraph)
    name = Faker::Lorem.characters(10)
    put :update, construct_params({ id: company.id }, custom_fields: [1, 2])
    match_json([bad_request_error_pattern(:custom_fields, :data_type_mismatch, data_type: 'key/value pair')])
    assert_response 400
  end

  def test_update_company_with_blank_name
    company = create_company(name: Faker::Lorem.characters(10), description: Faker::Lorem.paragraph)
    put :update, construct_params({ id: company.id }, name: '', description: Faker::Lorem.paragraph,
                                                      note: Faker::Lorem.characters(10), domains: domain_array,
                                                      custom_fields: { 'linetext' => Faker::Lorem.characters(10) })
    assert_response 400
    match_json([bad_request_error_pattern('name', :"can't be blank")])
  end

  def test_update_company_with_invalid_id
    put :update, construct_params({ id: Faker::Number.number(7).to_i }, name: Faker::Lorem.characters(10), description: Faker::Lorem.paragraph,
                                                                        note: Faker::Lorem.characters(10), domains: domain_array,
                                                                        custom_fields: { 'linetext' => Faker::Lorem.characters(10) })
    assert_equal ' ', @response.body
    assert_response :missing
  end

  def test_update_company_domains_invalid
    post :create, construct_params({}, description: Faker::Lorem.paragraph, name: Faker::Lorem.characters(10),
                                       domains: ['test,,,comma', 'test'])
    assert_response 400
    match_json([bad_request_error_pattern('domains', :special_chars_present, chars: ',')])
  end

  def test_update_company_with_invalid_fields
    company = create_company(name: Faker::Lorem.characters(10), description: Faker::Lorem.paragraph)
    put :update, construct_params({ id:  company.id }, name: Faker::Number.number(10).to_i, description: Faker::Number.number(10).to_i,
                                                       domains: domain_array)
    assert_response 400
    match_json([bad_request_error_pattern('name', :data_type_mismatch, data_type: 'String'),
                bad_request_error_pattern('description', :data_type_mismatch, data_type: 'String')])
  end

  def test_update_company_with_invalid_custom_field
    company = create_company(name: Faker::Lorem.characters(10), description: Faker::Lorem.paragraph)
    put :update, construct_params({ id: company.id }, name: Faker::Lorem.characters(10),
                                                      note: Faker::Lorem.characters(10), domains: domain_array,
                                                      custom_fields: { 'invalid' => Faker::Lorem.characters(10) })
    assert_response 400
    match_json([bad_request_error_pattern('invalid', :invalid_field)])
  end

  def test_update_length_invalid
    company = create_company(name: Faker::Lorem.characters(10), description: Faker::Lorem.paragraph)
    params_hash = { name: Faker::Lorem.characters(300) }
    put :update, construct_params({ id: company.id }, params_hash)
    match_json([bad_request_error_pattern('name', :"is too long (maximum is 255 characters)")])
    assert_response 400
  end

  def test_update_length_valid_trailing_spaces
    company = create_company(name: Faker::Lorem.characters(10), description: Faker::Lorem.paragraph)
    params_hash = { name: Faker::Lorem.characters(20) + white_space }
    put :update, construct_params({ id: company.id }, params_hash)
    assert_response 200
    match_json(company_pattern(params_hash.each { |x, y| y.strip! if [:name].include?(x) }, company.reload))
  end

  def test_delete_company
    company = create_company
    delete :destroy, construct_params(id: company.id)
    assert_response 204
    assert_equal ' ', 	@response.body
    assert_nil Company.find_by_id(company.id)
  end

  def test_show_company
    company = create_company
    get :show, construct_params(id: company.id)
    assert_response 200
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
    3.times do
      create_company
    end
    get :index, controller_params
    pattern = []
    Account.current.companies.order(:name).all.each do |company|
      pattern << company_pattern(Company.find(company.id))
    end
    assert_response 200
    match_json(pattern.ordered!)
  end

  def test_company_with_pagination_enabled
    3.times do
      create_company
    end
    get :index, controller_params(per_page: 1)
    assert_response 200
    assert JSON.parse(response.body).count == 1
    get :index, controller_params(per_page: 1, page: 2)
    assert_response 200
    assert JSON.parse(response.body).count == 1
    get :index, controller_params(per_page: 1, page: 3)
    assert_response 200
    assert JSON.parse(response.body).count == 1
  end

  def test_company_with_pagination_exceeds_limit
    get :index, controller_params(per_page: 101)
    assert_response 400
    match_json([bad_request_error_pattern('per_page', :gt_zero_lt_max_per_page, data_type: 'Positive Integer')])
  end

  def test_create_companies_with_invalid_domains
    post :create, construct_params({}, name: Faker::Lorem.characters(10), description: Faker::Lorem.paragraph,
                                       domains: Faker::Lorem.characters(10).to_i, note: Faker::Lorem.characters(10))
    assert_response 400
    match_json([bad_request_error_pattern('domains', :data_type_mismatch, data_type: 'Array')])
  end

  def test_create_companies_with_empty_domains
    post :create, construct_params({}, name: Faker::Lorem.characters(10), description: Faker::Lorem.paragraph,
                                       domains: [], note: Faker::Lorem.characters(10))
    assert_response 201
    match_json(company_pattern(Company.last))
  end

  def test_update_companies_with_invalid_domains_value
    post :create, construct_params({}, name: Faker::Lorem.characters(10), description: Faker::Lorem.paragraph,
                                       domains: [Faker::Lorem.characters(10).to_i, Faker::Lorem.characters(10)], note: Faker::Lorem.characters(10))
    assert_response 400
    match_json([bad_request_error_pattern('domains', :data_type_mismatch, data_type: 'String')])
  end

  def test_create_company_with_invalid_custom_field_values
    post :create, construct_params({}, name: Faker::Lorem.characters(10), description: Faker::Lorem.paragraph,
                                       domains: domain_array, note: Faker::Lorem.characters(10),
                                       custom_fields: { 'agt_count' => 'abc', 'date' => '2015-09-09T08:00:00+0530',
                                                        'show_all_ticket' => Faker::Number.number(5) })

    assert_response 400
    match_json([bad_request_error_pattern('agt_count', :data_type_mismatch, data_type: 'Integer'),
                bad_request_error_pattern('date', :invalid_date),
                bad_request_error_pattern('show_all_ticket', :data_type_mismatch, data_type: 'Boolean')])
  end

  def test_create_company_with_invalid_custom_dropdown_field_values
    dropdown_list = %w(First Second Third Freshman Tenth)
    post :create, construct_params({}, name: Faker::Lorem.characters(10), description: Faker::Lorem.paragraph,
                                       domains: domain_array, note: Faker::Lorem.characters(10),
                                       custom_fields: { 'category' =>  Faker::Lorem.characters(10) })

    assert_response 400
    match_json([bad_request_error_pattern('category', :not_included, list: dropdown_list.join(','))])
  end

  def test_create_company_with_valid_custom_field_values
    post :create, construct_params({}, name: Faker::Lorem.characters(10), description: Faker::Lorem.paragraph,
                                       domains: domain_array, note: Faker::Lorem.characters(10),
                                       custom_fields: { 'agt_count' => 21, 'date' => '2015-01-15',
                                                        'show_all_ticket' => false, 'category' => 'Second' })

    assert_response 201
    assert Company.last.custom_field['cf_show_all_ticket'] == false
    match_json(company_pattern(Company.last))
  end

  def test_update_company_with_invalid_custom_fields
    company = create_company(name: Faker::Lorem.characters(10), description: Faker::Lorem.paragraph)
    put :update, construct_params({ id: company.id }, name: Faker::Lorem.characters(10), description: Faker::Lorem.paragraph,
                                                      domains: domain_array, note: Faker::Lorem.characters(10),
                                                      custom_fields: { 'agt_count' => 'abc', 'date' => 'test_date',
                                                                       'show_all_ticket' => Faker::Number.number(5), 'file_url' =>  'test_url' })
    assert_response 400
    match_json([bad_request_error_pattern('agt_count', :data_type_mismatch, data_type: 'Integer'),
                bad_request_error_pattern('date', :invalid_date),
                bad_request_error_pattern('show_all_ticket', :data_type_mismatch, data_type: 'Boolean'),
                bad_request_error_pattern('file_url', 'invalid_format')])
  end

  def test_update_company_with_invalid_custom_dropdown_field_values
    dropdown_list = %w(First Second Third Freshman Tenth)
    company = create_company(name: Faker::Lorem.characters(10), description: Faker::Lorem.paragraph)
    put :update, construct_params({ id: company.id }, custom_fields: { 'category' =>  Faker::Lorem.characters(10) })
    assert_response 400
    match_json([bad_request_error_pattern('category', :not_included, list: dropdown_list.join(','))])
  end

  def test_update_company_with_duplicate_name
    company1 = create_company(name: Faker::Lorem.characters(10), description: Faker::Lorem.paragraph)
    company2 = create_company(name: Faker::Lorem.characters(10), description: Faker::Lorem.paragraph)
    put :update, construct_params({ id: company2.id }, name: company1.name)
    assert_response 409
    match_json([bad_request_error_pattern('name', :"has already been taken")])
  end

  def test_update_delete_existing_domains
    company = create_company(name: Faker::Lorem.characters(10), description: Faker::Lorem.paragraph, domains: domain_array)
    put :update, construct_params({ id: company.id }, domains: [])
    assert_response 200
    match_json(company_pattern(company.reload))
  end

  def test_create_company_without_required_custom_field
    field = { type: 'text', field_type: 'custom_text', label: 'required_linetext', required_for_agent: true }
    params = company_params(field)
    create_company_field params
    clear_contact_field_cache
    post :create, construct_params({}, name: Faker::Lorem.characters(10), description: Faker::Lorem.paragraph,
                                       domains: domain_array)
    cf = CompanyField.find_by_label('required_linetext')
    cf.destroy
    assert_response 400
    match_json([bad_request_error_pattern('required_linetext', :missing_field)])
  end

  def test_update_array_fields_with_compacting_array
    domain = Faker::Name.name
    company = create_company(name: Faker::Lorem.characters(10), description: Faker::Lorem.paragraph, domains: domain_array)
    put :update, construct_params({ id: company.id }, domains: [domain, '', '', nil])
    assert_response 200
    match_json(company_pattern({ domains: [domain] }, company.reload))
  end

  def test_index_with_link_header
    3.times do
      create_company
    end
    per_page =  Account.current.companies.all.count - 1
    get :index, controller_params(per_page: per_page)
    assert_response 200
    assert JSON.parse(response.body).count == per_page
    assert_equal "<http://#{@request.host}/api/v2/companies?per_page=#{per_page}&page=2>; rel=\"next\"", response.headers['Link']

    get :index, controller_params(per_page: per_page, page: 2)
    assert_response 200
    assert JSON.parse(response.body).count == 1
    assert_nil response.headers['Link']
  end

  def test_create_with_all_default_fields_required_invalid
    default_non_required_fiels = CompanyField.where(required_for_agent: false, column_name: 'default')
    default_non_required_fiels.map { |x| x.toggle!(:required_for_agent) }
    post :create, construct_params({},  name: Faker::Name.name)
    assert_response 400
    match_json([bad_request_error_pattern('description', :required_and_data_type_mismatch, data_type: 'String'),
                bad_request_error_pattern('domains', :required_and_data_type_mismatch, data_type: 'Array'),
                bad_request_error_pattern('note', :required_and_data_type_mismatch, data_type: 'String')])
  ensure
    default_non_required_fiels.map { |x| x.toggle!(:required_for_agent) }
  end

  def test_create_with_all_default_fields_required_valid
    default_non_required_fiels = ContactField.where(required_for_agent: false,  column_name: 'default')
    default_non_required_fiels.map { |x| x.toggle!(:required_for_agent) }
    post :create, construct_params({},  name: Faker::Lorem.characters(15),
                                        note: Faker::Lorem.characters(15),
                                        description: Faker::Lorem.characters(300),
                                        domains: [Faker::Name.name, Faker::Name.name]
                                  )
    assert_response 201
  ensure
    default_non_required_fiels.map { |x| x.toggle!(:required_for_agent) }
  end

  def test_update_with_all_default_fields_required_invalid
    default_non_required_fiels = CompanyField.where(required_for_agent: false,  column_name: 'default')
    default_non_required_fiels.map { |x| x.toggle!(:required_for_agent) }
    put :update, construct_params({ id: company.id },  domains: [],
                                                       description: nil,
                                                       note: nil)
    assert_response 400
    match_json([bad_request_error_pattern('note', :data_type_mismatch, data_type: 'String'),
                bad_request_error_pattern('description', :data_type_mismatch, data_type: 'String'),
                bad_request_error_pattern('domains', :"can't be blank", data_type: 'Array')])
  ensure
    default_non_required_fiels.map { |x| x.toggle!(:required_for_agent) }
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
