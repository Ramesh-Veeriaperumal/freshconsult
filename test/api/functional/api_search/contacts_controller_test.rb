require_relative '../../test_helper'
module ApiSearch
  class ContactsControllerTest < ActionController::TestCase
    include SearchTestHelper

    def setup
      super
      initial_setup
    end

    @@initial_setup_run = false

    def initial_setup
      return if @@initial_setup_run
      clear_es(@account.id)
      create_contact_field(company_params({ :type=>"text", :field_type=>"custom_text", :label=>"sample_text", :editable_in_signup=> "true"}))
      create_contact_field(company_params({ :type=>"number", :field_type=>"custom_number", :label=>"sample_number", :editable_in_signup=> "true"}))
      create_contact_field(company_params({ :type=>"checkbox", :field_type=>"custom_checkbox", :label=>"sample_checkbox", :editable_in_signup => "true"}))
      30.times { create_search_contact(contact_params_hash) }
      write_data_to_es(@account.id)
      @@initial_setup_run = true
    end

    def wrap_cname(params)
      { api_search: params }
    end

    def contact_params_hash
      email = Faker::Internet.email
      twitter_id = Faker::Internet.user_name
      company_id = @account.company_ids[rand(3)]
      mobile = Faker::Number.number(10) 
      phone = Faker::Number.number(10)
      custom_fields = { cf_sample_number: rand(5) + 1, cf_sample_checkbox: rand(5) % 2 ? true : false, cf_sample_text: Faker::Lorem.words(1) }
      params_hash = { email: email, twitter_id: twitter_id, customer_id: company_id, mobile: mobile, phone: phone,
                      custom_field: custom_fields}
      params_hash
    end

    def test_tickets_invalid_query_format
      get :index, controller_params(query: "company_id:1 OR company_id:2")
      assert_response 400
      match_json([bad_request_error_pattern('query', :query_format_invalid)])
    end

    def test_contacts_custom_fields
      contacts = @account.contacts.select{|x| x.custom_field["cf_sample_number"] == 1 || x.custom_field["cf_sample_checkbox"] == false || x.company_id == 2 }
      get :index, controller_params(query: '"sample_number:1 OR sample_checkbox:false OR company_id:2"')
      assert_response 200
      response = parse_response @response.body
      pattern = contacts.map { |contact| index_contact_pattern(contact) }
      match_json({results: pattern, total: contacts.size})
    end
  end
end