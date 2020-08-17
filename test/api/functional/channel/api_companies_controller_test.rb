require_relative '../../test_helper'
module Channel
  class ApiCompaniesControllerTest < ActionController::TestCase
    include CompaniesTestHelper

    def wrap_cname(params)
      { api_company: params }
    end

    def setup
      super
    end

    def domain_array
      [Faker::Lorem.characters(6), Faker::Lorem.characters(5)]
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

    def clear_contact_field_cache
      key = MemcacheKeys::COMPANY_FORM_FIELDS % { account_id: @account.id, company_form_id: @account.company_form.id }
      MemcacheKeys.delete_from_cache key
    end

    def test_create_company
      set_jwt_auth_header('zapier')
      post :create, construct_params({version: 'channel'}, name: Faker::Lorem.characters(10), description: Faker::Lorem.paragraph,
                                         domains: domain_array, note: Faker::Lorem.characters(10))
      assert_response 201
      match_json(v2_company_pattern(Company.last))
    end

    def test_create_company_with_duplicate_name
      name = Faker::Lorem.characters(10)
      company = create_company(name: name, description: Faker::Lorem.paragraph)
      set_jwt_auth_header('zapier')
      post :create, construct_params({version: 'channel'}, name: name, description: Faker::Lorem.paragraph,
                                         domains: domain_array, note: Faker::Lorem.characters(10))
      assert_response 409
      additional_info = parse_response(@response.body)['errors'][0]['additional_info']
      assert_equal additional_info['company_id'], company.id
      match_json([bad_request_error_pattern_with_additional_info('name', additional_info, :'has already been taken')])
    end

    def test_create_company_with_duplicate_domain
      name = Faker::Lorem.characters(10)
      company = create_company(name: name)
      domains = company.domains.split(',')
      set_jwt_auth_header('zapier')
      post :create, construct_params({version: 'channel'}, name: Faker::Lorem.characters(10), domains: domains, note: Faker::Lorem.characters(10))
      assert_response 409
      response = parse_response @response.body
      error_message = response['errors'][0]['message']
      assert_equal error_message, domains[0] + ' is already taken by the company with company id:' + company.id.to_s
    end

    def test_create_avatar_id_validation_failure
      set_jwt_auth_header('zapier')
      invalid_avatar_ids = [9999]
      post :create, construct_params({ version: 'channel' }, name: Faker::Lorem.characters(10), description: Faker::Lorem.paragraph, domains: domain_array, avatar_id: invalid_avatar_ids.first)
      assert_response 400
      match_json([bad_request_error_pattern('avatar_id', :invalid_list, list: invalid_avatar_ids)])
    end

    def test_create_company_without_required_custom_field
      field = { type: 'text', field_type: 'custom_text', label: 'required_linetext', required_for_agent: true }
      params = company_params(field)
      create_company_field params
      clear_contact_field_cache
      set_jwt_auth_header('zapier')
      post :create, construct_params({version: 'channel'}, name: Faker::Lorem.characters(10), description: Faker::Lorem.paragraph,
                                         domains: domain_array)
      cf = CompanyField.find_by_label('required_linetext')
      cf.destroy
      assert_response 201
      match_json(v2_company_pattern(Company.last))
    end

    def test_create_company_without_jwt_header
      post :create, construct_params({version: 'channel'}, name: Faker::Lorem.characters(10), description: Faker::Lorem.paragraph,
                                         domains: domain_array, note: Faker::Lorem.characters(10))
      assert_response 401
    end
  end

end
