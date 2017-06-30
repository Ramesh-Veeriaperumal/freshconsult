require_relative '../../test_helper'
module ApiSearch
  class CompaniesControllerTest < ActionController::TestCase
    include SearchTestHelper

    def setup
      super
      initial_setup
    end

    @@initial_setup_run = false

    def initial_setup
      return if @@initial_setup_run
      clear_es(@account.id)
      create_company_field(company_params({ :type=>"text", :field_type=>"custom_text", :label=>"sample_text", :editable_in_signup=> "true"}))
      create_company_field(company_params({ :type=>"number", :field_type=>"custom_number", :label=>"sample_number", :editable_in_signup=> "true"}))
      create_company_field(company_params({ :type=>"checkbox", :field_type=>"custom_checkbox", :label=>"sample_checkbox", :editable_in_signup => "true"}))
      30.times { create_search_company(company_params_hash) }
      write_data_to_es(@account.id)
      @@initial_setup_run = true
    end

    def wrap_cname(params)
      { api_search: params }
    end

    def company_params_hash
      name = Faker::Company.name
      description = Faker::Lorem.sentence
      domains = "#{Faker::Internet.domain_name},#{Faker::Internet.domain_name}"
      custom_fields = { cf_sample_number: rand(5) + 1, cf_sample_checkbox: rand(5) % 2 ? true : false, cf_sample_text: Faker::Lorem.words(1) }
      params_hash = { name: name, description: description, domains: domains, custom_field: custom_fields}
      params_hash
    end

    def test_companies_custom_fields
      companies = @account.companies.select{|x| x.custom_field["cf_sample_number"] == 2 || x.custom_field["cf_sample_checkbox"] == false || x.domains.split(",").include?('aaa.aa') }
      get :index, controller_params(query: '"domain:\'aaa.aa\' OR sample_checkbox:false OR sample_number:2"')
      assert_response 200
      response = parse_response @response.body
      assert_equal companies.size, response["results"].size
    end
  end
end