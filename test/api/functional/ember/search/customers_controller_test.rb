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
        Search::V2::QueryHandler.any_instance.stubs(:query_results).returns(Search::V2::PaginationWrapper.new([contact], { total_entries: 0 }))
        post :results, construct_params(version: 'private', context: 'spotlight', term: contact.name, limit: 3)
        Search::V2::QueryHandler.any_instance.unstub(:query_results)
        assert_response 200
        match_json([contact_pattern(contact)])
      end
    end

    def test_results_with_valid_params_for_company
      enable_multiple_user_companies do
        company = create_company
        add_avatar_to_company(company)
        Search::V2::QueryHandler.any_instance.stubs(:query_results).returns(Search::V2::PaginationWrapper.new([company], { total_entries: 0 }))
        post :results, construct_params(version: 'private', context: 'spotlight', term: company.name, limit: 3)
        Search::V2::QueryHandler.any_instance.unstub(:query_results)
        assert_response 200
        assert_equal [company_pattern(company)].to_json, response.body
      end
    end

    def test_results_with_merge_context
      companies = [create_company, create_company]
      companies.each { |company| add_avatar_to_company(company) }
      contact = create_contact_with_other_companies(@account, companies.map(&:id))
      add_avatar_to_user(contact)
      source_user = create_contact_with_other_companies(@account, companies.map(&:id))
      add_avatar_to_user(source_user)
      Search::V2::QueryHandler.any_instance.stubs(:query_results).returns(Search::V2::PaginationWrapper.new([contact], { total_entries: 0 }))
      post :results, construct_params(version: 'private', context: 'merge', term: contact.name, source_user_id: source_user.id, limit: 3)
      Search::V2::QueryHandler.any_instance.unstub(:query_results)
      assert_response 200
      match_json([contact_pattern(contact)])
    end

    def test_results_with_freshcaller_context
      enable_multiple_user_companies do
        companies = [create_company, create_company]
        companies.each { |company| add_avatar_to_company(company) }
        contact = create_contact_with_other_companies(@account, companies.map(&:id))
        add_avatar_to_user(contact)
        Search::V2::QueryHandler.any_instance.stubs(:query_results).returns(Search::V2::PaginationWrapper.new([contact], { total_entries: 0 }))
        post :results, construct_params(version: 'private', context: 'freshcaller', term: contact.name, limit: 3)
        Search::V2::QueryHandler.any_instance.unstub(:query_results)
        assert_response 200
        match_json([contact_pattern(contact)])
      end
    end

    def test_results_with_filteredContactSearch_context
      enable_multiple_user_companies do
        companies = [create_company, create_company]
        companies.each { |company| add_avatar_to_company(company) }
        contact = create_contact_with_other_companies(@account, companies.map(&:id))
        add_avatar_to_user(contact)
        Search::V2::QueryHandler.any_instance.stubs(:query_results).returns(Search::V2::PaginationWrapper.new([contact], { total_entries: 0 }))
        post :results, construct_params(version: 'private', context: 'filteredContactSearch', term: contact.name, all: true, limit: 3)
        Search::V2::QueryHandler.any_instance.unstub(:query_results)
        assert_response 200
        match_json([contact_pattern(contact)])
      end
    end

    def test_results_with_filteredCompanySearch_context
      enable_multiple_user_companies do
        company = create_company
        add_avatar_to_company(company)
        Search::V2::QueryHandler.any_instance.stubs(:query_results).returns(Search::V2::PaginationWrapper.new([company], { total_entries: 0 }))
        post :results, construct_params(version: 'private', context: 'filteredCompanySearch', term: company.name, all: true, limit: 3)
        Search::V2::QueryHandler.any_instance.unstub(:query_results)
        assert_response 200
        assert_equal [company_pattern(company)].to_json, response.body
      end
    end
  end
end