require_relative '../../test_helper'
module ApiSearch
  class CompaniesControllerTest < ActionController::TestCase
    include SearchTestHelper

    CHOICES = ['Test Dropdown1', 'Test Dropdown2', 'Test Dropdown3'].freeze

    def setup
      super
      initial_setup
    end

    @@initial_setup_run = false

    def initial_setup
      return if @@initial_setup_run

      @account.launch(:service_writes)
      create_company_field(company_params(type: 'text', field_type: 'custom_text', label: 'sample_text', editable_in_signup: 'true'))
      create_company_field(company_params(type: 'number', field_type: 'custom_number', label: 'sample_number', editable_in_signup: 'true'))
      create_company_field(company_params(type: 'checkbox', field_type: 'custom_checkbox', label: 'sample_checkbox', editable_in_signup: 'true'))
      create_company_field(company_params(type: 'date', field_type: 'custom_date', label: 'sample_date', editable_in_signup: 'true'))

      create_company_field(company_params(type: 'text', field_type: 'custom_dropdown', label: 'sample_dropdown', editable_in_signup: 'true'))

      cfid = CompanyField.find_by_name('cf_sample_dropdown').id
      CompanyFieldChoice.create(value: CHOICES[0], position: 1)
      CompanyFieldChoice.create(value: CHOICES[1], position: 2)
      CompanyFieldChoice.create(value: CHOICES[2], position: 3)
      CompanyFieldChoice.where('value LIKE ?', '%Test Dropdown%').update_all(account_id: @account.id)
      CompanyFieldChoice.where('value LIKE ?', '%Test Dropdown%').update_all(company_field_id: cfid)

      @account.reload
      30.times { create_search_company(company_params_hash) }
      @account.companies.last(5).map { |x| x.update_attributes('cf_sample_date' => nil) }
      @@initial_setup_run = true
    end

    def wrap_cname(params)
      { api_search: params }
    end

    def company_params_hash
      special_chars = ['!', '#', '$', '%', '&', '(', ')', '*', '+', ',', '-', '.', '/', ':', ';', '<', '=', '>', '?', '@', '[', '\\', ']', '^', '_', '`', '{', '|', '}', '~']
      name = Faker::Company.name
      description = Faker::Lorem.sentence
      domains = "#{Faker::Internet.domain_name},#{Faker::Internet.domain_name}"
      n = rand(10)
      custom_fields = { cf_sample_number: n + 1, cf_sample_checkbox: rand(5) % 2 ? true : false, cf_sample_text: Faker::Lorem.word + ' ' + special_chars.join, cf_sample_date: rand(10).days.until, cf_sample_dropdown: CHOICES[rand(3)] }
      custom_fields[:cf_sample_number] = nil if n % 3 == 0
      custom_fields[:cf_sample_text] = nil if n % 4 == 0
      custom_fields[:cf_sample_date] = nil if n < 3 == 0

      params_hash = { name: name, description: description, domains: domains, custom_field: custom_fields, created_at: n.days.until.iso8601, updated_at: (n + 2).days.until.iso8601 }
      params_hash[:domains] = nil if n < 3
      params_hash
    end

    def test_companies_custom_fields
      companies = @account.companies.select { |x| x.custom_field['cf_sample_number'] == 2 || x.custom_field['cf_sample_checkbox'] == false || x.domains.split(',').include?('aaa.aa') }
      stub_public_search_response(companies) do
        get :index, controller_params(query: '"domain:\'aaa.aa\' OR sample_checkbox:false OR sample_number:2"')
      end
      assert_response 200
      response = parse_response @response.body
      assert_equal companies.size, response['results'].size
    end

    def test_companies_domains_null
      companies = @account.companies.select { |x| x.domains.blank? }
      stub_public_search_response(companies) do
        get :index, controller_params(query: '"domain: null"')
      end
      assert_response 200
      pattern = companies.map { |company| public_search_company_pattern(company) }
      match_json(results: pattern, total: companies.size)
    end

    # Custom Fields
    def test_companies_custom_dropdown_null
      companies = @account.companies.select { |x| x.cf_sample_dropdown.nil? }
      stub_public_search_response(companies) do
        get :index, controller_params(query: '"sample_dropdown: null"')
      end
      assert_response 200
      pattern = companies.map { |company| public_search_company_pattern(company) }
      match_json(results: pattern, total: companies.size)
    end

    def test_companies_custom_dropdown_valid_choice
      choice = CHOICES[rand(3)]
      companies = @account.companies.select { |x| x.cf_sample_dropdown == choice }
      stub_public_search_response(companies) do
        get :index, controller_params(query: '"sample_dropdown:\'' + choice + '\' "')
      end
      assert_response 200
      pattern = companies.map { |company| public_search_company_pattern(company) }
      match_json(results: pattern, total: companies.size)
    end

    def test_companies_custom_dropdown_invalid_choice
      get :index, controller_params(query: '"sample_dropdown:aaabbbccc"')
      assert_response 400
      match_json([bad_request_error_pattern('sample_dropdown', :not_included, list: CHOICES.join(','))])
    end

    def test_companies_custom_dropdown_combined_condition
      choice = CHOICES[rand(3)]
      domain = @account.companies.map(&:domains).map { |x| x.split(',') }.flatten.compact.first
      companies = @account.companies.select { |x| x.cf_sample_dropdown == choice && x.domains.split(',').include?(domain) }
      stub_public_search_response(companies) do
        get :index, controller_params(query: '"sample_dropdown:\'' + choice + '\' AND domain:\'' + domain + '\'"')
      end
      assert_response 200
      pattern = companies.map { |company| public_search_company_pattern(company) }
      match_json(results: pattern, total: companies.size)
    end

    def test_companies_custom_number_null
      companies = @account.companies.select { |x| x.cf_sample_number.nil? }
      stub_public_search_response(companies) do
        get :index, controller_params(query: '"sample_number: null"')
      end
      assert_response 200
      pattern = companies.map { |company| public_search_company_pattern(company) }
      match_json(results: pattern, total: companies.size)
    end

    def test_companies_custom_fields_string_value_for_custom_number
      get :index, controller_params(query: '"sample_number:\'123\'"')
      assert_response 400
    end

    def test_companies_custom_text_null
      companies = @account.companies.select { |x| x.cf_sample_text.nil? }
      stub_public_search_response(companies) do
        get :index, controller_params(query: '"sample_text: null"')
      end
      assert_response 200
      pattern = companies.map { |company| public_search_company_pattern(company) }
      match_json(results: pattern, total: companies.size)
    end

    def test_companies_custom_text_special_characters
      text = @account.companies.map(&:cf_sample_text).compact.last(2)
      companies = @account.companies.select { |x| text.include?(x.cf_sample_text) }
      stub_public_search_response(companies) do
        get :index, controller_params(query: "\"sample_text:'#{text[0]}' or sample_text:'#{text[1]}'\"")
      end
      assert_response 200
      pattern = companies.map { |company| public_search_company_pattern(company) }
      match_json(results: pattern, total: companies.size)
    end

    def test_companies_custom_text_invalid_special_characters
      get :index, controller_params(query: "\"sample_text:'aaa\'a' or sample_text:'aaa\"aa'\"")
      assert_response 400
    end

    def test_companies_filter_using_custom_checkbox
      companies = @account.companies.select { |x| x.cf_sample_checkbox == true }
      stub_public_search_response(companies) do
        get :index, controller_params(query: '"sample_checkbox:true"')
      end
      assert_response 200
      pattern = companies.map { |company| public_search_company_pattern(company) }
      match_json(results: pattern, total: companies.size)
    end

    def test_companies_invalid_date_format
      get :index, controller_params(query: '"created_at:>\'20170707\'"')
      assert_response 400
      match_json([bad_request_error_pattern('query', :query_format_invalid)])
    end

    def test_companies_valid_date
      d1 = (Date.today - 1).iso8601
      companies = @account.companies.select { |x| x.created_at.utc.to_date.iso8601 <= d1 }
      stub_public_search_response(companies) do
        get :index, controller_params(query: '"created_at :< \'' + d1 + '\'"')
      end
      assert_response 200
      pattern = companies.map { |company| public_search_company_pattern(company) }
      match_json(results: pattern, total: companies.size)
    end

    def test_companies_valid_range
      d1 = (Date.today - 8).iso8601
      d2 = (Date.today - 1).iso8601
      companies = @account.companies.select { |x| x.created_at.utc.to_date.iso8601 >= d1 && x.created_at.utc.to_date.iso8601 <= d2 }
      stub_public_search_response(companies) do
        get :index, controller_params(query: '"(created_at :> \'' + d1 + '\' AND created_at :< \'' + d2 + '\')"')
      end
      assert_response 200
      pattern = companies.map { |company| public_search_company_pattern(company) }
      match_json(results: pattern, total: companies.size)
    end

    def test_companies_valid_range_and_filter
      d1 = (Date.today - 8).iso8601
      d2 = (Date.today - 1).iso8601
      companies = @account.companies.select { |x| (x.created_at.utc.to_date.iso8601 >= d1 && x.created_at.utc.to_date.iso8601 <= d2) }
      stub_public_search_response(companies) do
        get :index, controller_params(query: '"(created_at :> \'' + d1 + '\' AND created_at :< \'' + d2 + '\')"')
      end
      assert_response 200
      pattern = companies.map { |company| public_search_company_pattern(company) }
      match_json(results: pattern, total: companies.size)
    end

    def test_companies_created_on_a_day
      d1 = Date.today.to_date.iso8601
      companies = @account.companies.select { |x| x.created_at.utc.to_date.iso8601 == d1 }
      stub_public_search_response(companies) do
        get :index, controller_params(query: '"created_at: \'' + d1 + '\'"')
      end
      assert_response 200
      response = parse_response @response.body
      assert response['total'] == companies.size
    end

    def test_companies_updated_on_a_day
      d1 = (Date.today + 2).to_date.iso8601
      companies = @account.companies.select { |x| x.updated_at.utc.to_date.iso8601 == d1 }
      stub_public_search_response(companies) do
        get :index, controller_params(query: '"updated_at: \'' + d1 + '\'"')
      end
      assert_response 200
      response = parse_response @response.body
      assert response['total'] == companies.size
    end

    # custom date not allowed
    def test_companies_custom_date
      d1 = Date.today.to_date.iso8601
      get :index, controller_params(query: '"sample_date: \'' + d1 + '\'"')
      assert_response 400
      match_json([bad_request_error_pattern('sample_date', :invalid_field)])
    end

    def test_companies_combined_condition
      choice = CHOICES[rand(3)]
      d1 = Date.today.to_date.iso8601
      domain = @account.companies.map(&:domains).map { |x| x.split(',') }.flatten.compact.first
      companies = @account.companies.select { |x| x.cf_sample_dropdown == choice && x.domains.split(',').include?(domain) && x.cf_sample_checkbox == true && x.cf_sample_text.nil? && x.created_at.utc.to_date.iso8601 == d1 }
      stub_public_search_response(companies) do
        get :index, controller_params(query: '"sample_dropdown:\'' + choice + '\' AND domain:\'' + domain + '\' AND sample_checkbox:true AND sample_text:null AND created_at:\'' + d1 + '\'"')
      end
      assert_response 200
      pattern = companies.map { |company| public_search_company_pattern(company) }
      match_json(results: pattern, total: companies.size)
    end
  end
end
