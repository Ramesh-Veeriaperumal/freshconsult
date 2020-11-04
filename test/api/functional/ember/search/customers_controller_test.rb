require_relative '../../../test_helper'
['company_test_helper.rb'].each { |file| require "#{Rails.root}/test/core/helpers/#{file}" }

module Ember::Search
  class CustomersControllerTest < ActionController::TestCase
    include CompanyTestHelper
    include UsersTestHelper
    include CompaniesTestHelper
    include SearchTestHelper

    def test_results_without_user_access
      @controller.stubs(:api_current_user).raises(ActiveSupport::MessageVerifier::InvalidSignature)
      post :results, construct_params({version: "private", context: "spotlight", term:  Faker::Lorem.words, searchSort:"relevance"})
      assert_response 401
      assert_equal request_error_pattern(:credentials_required).to_json, response.body
    end

    def test_results_with_valid_params_for_contact
      enable_multiple_user_companies do
        companies = [create_company, create_company]
        companies.each { |company| add_avatar_to_company(company) }
        contact = create_contact_with_other_companies(@account, companies.map(&:id))
        add_avatar_to_user(contact)
        stub_private_search_response([contact]) do
          post :results, construct_params(version: 'private', context: 'spotlight', term: contact.name, limit: 3)
        end
        assert_response 200
        match_json([private_search_contact_pattern(contact)])
      end
    end

    def test_results_with_valid_params_for_company
      enable_multiple_user_companies do
        company = create_company
        add_avatar_to_company(company)
        stub_private_search_response([company]) do
          post :results, construct_params(version: 'private', context: 'spotlight', term: company.name, limit: 3)
        end
        assert_response 200
        assert_equal [private_search_company_pattern(company)].to_json, response.body
      end
    end

    def test_results_with_merge_context
      companies = [create_company, create_company]
      companies.each { |company| add_avatar_to_company(company) }
      contact = create_contact_with_other_companies(@account, companies.map(&:id))
      add_avatar_to_user(contact)
      source_user = create_contact_with_other_companies(@account, companies.map(&:id))
      add_avatar_to_user(source_user)
      stub_private_search_response([contact]) do
        post :results, construct_params(version: 'private', context: 'merge', term: contact.name, source_user_id: source_user.id, limit: 3)
      end
      assert_response 200
      match_json([private_search_contact_pattern(contact)])
    end

    def test_results_with_freshcaller_context
      enable_multiple_user_companies do
        companies = [create_company, create_company]
        companies.each { |company| add_avatar_to_company(company) }
        contact = create_contact_with_other_companies(@account, companies.map(&:id))
        add_avatar_to_user(contact)
        stub_private_search_response([contact]) do
          post :results, construct_params(version: 'private', context: 'freshcaller', term: contact.name, limit: 3)
        end
        assert_response 200
        match_json([private_search_contact_pattern(contact)])
      end
    end

    def test_results_with_freshcaller_context_search_with_sanitized_phone_fields
      enable_multiple_user_companies do
        companies = [create_company, create_company]
        companies.each { |company| add_avatar_to_company(company) }
        contact = create_contact_with_other_companies(@account, companies.map(&:id))
        User.update(contact.id, phone: '(044) 1234  567', mobile: '+91 (1234) 567 890')
        add_avatar_to_user(contact)
        stub_private_search_response([contact]) do
          post :results, construct_params(version: 'private', context: 'freshcaller', term: contact.phone, limit: 3)
        end
        assert_response 200
        match_json([private_search_contact_pattern(contact)])

        stub_private_search_response([contact]) do
          post :results, construct_params(version: 'private', context: 'freshcaller', term: contact.mobile, limit: 3)
        end
        assert_response 200
        match_json([private_search_contact_pattern(contact)])
      end
    end

    def test_results_with_freshcaller_context_search_with_most_recently_updated_contacts
      enable_multiple_user_companies do
        companies = [create_company, create_company]
        companies.each { |company| add_avatar_to_company(company) }
        contacts = []
        3.times do
          contact = create_contact_with_other_companies(@account, companies.map(&:id))
          add_avatar_to_user(contact)
          User.update(contact.id, phone: '(044) 1234  5678')
          contact.reload
          contacts << contact
          sleep 1 # delay introduced so that contacts are not updated at the same time. Fractional seconds are ignored in tests.
        end
        stub_private_search_response(contacts.reverse) do
          post :results, construct_params(version: 'private', context: 'freshcaller', term: contacts[0].phone, limit: 3)
        end
        assert_response 200
        pattern = []
        Account.current.all_users.where(phone: '(044) 1234  5678').order('updated_at DESC').each do |contact|
          pattern << private_search_contact_pattern(contact)
        end
        match_json(pattern.ordered!)
      end
    end

    def test_results_with_filteredContactSearch_context
      enable_multiple_user_companies do
        companies = [create_company, create_company]
        companies.each { |company| add_avatar_to_company(company) }
        contact = create_contact_with_other_companies(@account, companies.map(&:id))
        add_avatar_to_user(contact)
        stub_private_search_response([contact]) do
          post :results, construct_params(version: 'private', context: 'filteredContactSearch', term: contact.name, all: true, limit: 3)
        end
        assert_response 200
        match_json([private_search_contact_pattern(contact)])
      end
    end

    def test_results_with_filteredCompanySearch_context
      enable_multiple_user_companies do
        company = create_company
        add_avatar_to_company(company)
        stub_private_search_response([company]) do
          post :results, construct_params(version: 'private', context: 'filteredCompanySearch', term: company.name, all: true, limit: 3)
        end
        assert_response 200
        assert_equal [private_search_company_pattern(company)].to_json, response.body
      end
    end

    def test_results_with_valid_params_for_contact_only_count
      enable_multiple_user_companies do
        companies = [create_company, create_company]
        companies.each { |company| add_avatar_to_company(company) }
        contact = create_contact_with_other_companies(@account, companies.map(&:id))
        add_avatar_to_user(contact)
        stub_private_search_response([contact]) do
          post :results, construct_params(version: 'private', context: 'spotlight', term: contact.name, only: 'count')
        end
        assert_response 200
        assert_equal response.api_meta[:count], 1
        match_json []
      end
    end

    def test_results_with_valid_params_for_company_only_count
      enable_multiple_user_companies do
        company = create_company
        add_avatar_to_company(company)
        stub_private_search_response([company]) do
          get :results, construct_params(version: 'private', only: 'count', term: company.name)
        end
        assert_response 200
        assert_equal response.api_meta[:count], 1
        match_json []
      end
    end

    def test_results_with_filtered_contact_search_context_only_count
      enable_multiple_user_companies do
        companies = [create_company, create_company]
        companies.each { |company| add_avatar_to_company(company) }
        contact = create_contact_with_other_companies(@account, companies.map(&:id))
        add_avatar_to_user(contact)
        stub_private_search_response([contact]) do
          get :results, construct_params(version: 'private', context: 'filteredContactSearch', term: contact.name, all: true, only: 'count')
        end
        assert_response 200
        assert_equal response.api_meta[:count], 1
        match_json []
      end
    end

    def test_results_with_filtered_company_search_context_only_count
      enable_multiple_user_companies do
        company = create_company
        add_avatar_to_company(company)
        stub_private_search_response([company]) do
          get :results, construct_params(version: 'private', context: 'filteredCompanySearch', term: company.name, all: true, only: 'count')
        end
        assert_response 200
        assert_equal response.api_meta[:count], 1
        match_json []
      end
    end
  end
end