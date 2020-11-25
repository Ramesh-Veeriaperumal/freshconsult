# frozen_string_literal: true

require_relative '../../../test_helper'
['companies_test_helper.rb', 'users_test_helper.rb', 'groups_test_helper.rb'].each { |file| require Rails.root.join('test', 'core', 'helpers', file) }
['tag_test_helper.rb'].each { |file| require Rails.root.join('test', 'models', 'helpers', file) }

class ApiSearch::AutocompleteControllerTest < ActionController::TestCase
  include PrivilegesHelper
  include ModelsCompaniesTestHelper
  include CoreUsersTestHelper
  include TagTestHelper
  include GroupsTestHelper
  ES_DELAY_TIME = 5

  def test_requester_with_complete_name
    user = add_new_user(@account, email: 'test-requester.for_es@freshpo.com')
    sleep ES_DELAY_TIME # Delaying for sidekiq to send to ES
    Search::V2::QueryHandler.any_instance.stubs(:query_results).returns(Search::V2::PaginationWrapper.new([user], total_entries: 1))
    post :requesters, construct_params(term: user.name)
    assert_response 200
    res_body = parse_response(@response.body).map { |item| item['id'] }
    assert_includes res_body, user.id
    SearchService::QueryHandler.any_instance.unstub(:query_results)
  end

  def test_requester_with_name_auto_complete_disabled
    user = add_new_user(@account, email: 'test-requester.for_es@freshpo.com')
    sleep ES_DELAY_TIME # Delaying for sidekiq to send to ES

    disable_auto_complete
    post :requesters, construct_params(term: user.name)

    res_body = parse_response(@response.body).map { |item| item['id'] }
    assert_empty res_body
    assert_response 200

    rollback_auto_complete
  end

  def test_requester_with_name_auto_complete_off_view_contacts_privilege_on
    user = add_new_user(@account, email: 'test-requester.for_es@freshpo.com')
    sleep ES_DELAY_TIME # Delaying for sidekiq to send to ES

    @account.launch(:auto_complete_off)
    Search::V2::QueryHandler.any_instance.stubs(:query_results).returns(Search::V2::PaginationWrapper.new([user], total_entries: 1))
    post :requesters, construct_params(term: user.name)

    res_body = parse_response(@response.body).map { |item| item['id'] }
    assert_includes res_body, user.id
    assert_response 200
    @account.rollback(:auto_complete_off)
    SearchService::QueryHandler.any_instance.unstub(:query_results)
  end

  def test_requester_with_email_auto_complete_disabled
    user = add_new_user(@account, email: 'test-requester.for_es@freshpo.com')
    sleep ES_DELAY_TIME # Delaying for sidekiq to send to ES

    disable_auto_complete
    Search::V2::QueryHandler.any_instance.stubs(:query_results).returns(Search::V2::PaginationWrapper.new([user], total_entries: 1))
    post :requesters, construct_params(term: user.email)

    res_body = parse_response(@response.body).map { |item| item['id'] }
    assert_includes res_body, user.id
    assert_response 200
    rollback_auto_complete
    SearchService::QueryHandler.any_instance.unstub(:query_results)
  end

  def test_requester_with_partial_email_auto_complete_disabled
    user = add_new_user(@account, email: 'test-requester.for_es@freshpo.com')
    sleep ES_DELAY_TIME # Delaying for sidekiq to send to ES

    disable_auto_complete

    post :requesters, construct_params(term: user.email.split('@').first)

    res_body = parse_response(@response.body).map { |item| item['id'] }
    assert_empty res_body
    assert_response 200

    rollback_auto_complete
  end

  def test_requester_with_phone_number_auto_complete_disabled
    user = add_new_user_without_email(@account)
    sleep ES_DELAY_TIME # Delaying for sidekiq to send to ES

    disable_auto_complete

    post :requesters, construct_params(term: user.phone)

    res_body = parse_response(@response.body).map { |item| item['id'] }
    assert_empty res_body
    assert_response 200

    rollback_auto_complete
  end

  def test_requester_with_partial_name
    user = add_new_user(@account, email: 'test-requester.for_es@freshpo.com')
    sleep ES_DELAY_TIME # Delaying for sidekiq to send to ES
    Search::V2::QueryHandler.any_instance.stubs(:query_results).returns(Search::V2::PaginationWrapper.new([user], total_entries: 1))
    post :requesters, construct_params(term: user.name[0..5])
    res_body = parse_response(@response.body).map { |item| item['id'] }
    assert_includes res_body, user.id
    assert_response 200
    SearchService::QueryHandler.any_instance.unstub(:query_results)
  end

  def test_requester_with_complete_email
    user = add_new_user(@account, email: 'test-requester.for_es@freshpo.com')
    sleep ES_DELAY_TIME # Delaying for sidekiq to send to ES
    Search::V2::QueryHandler.any_instance.stubs(:query_results).returns(Search::V2::PaginationWrapper.new([user], total_entries: 1))

    post :requesters, construct_params(term: user.email)

    res_body = parse_response(@response.body).map { |item| item['id'] }
    assert_includes res_body, user.id
    assert_response 200
    SearchService::QueryHandler.any_instance.unstub(:query_results)
  end

  def test_requester_with_partial_email
    user = add_new_user(@account, email: 'test-requester.for_es@freshpo.com')
    sleep ES_DELAY_TIME # Delaying for sidekiq to send to ES
    Search::V2::QueryHandler.any_instance.stubs(:query_results).returns(Search::V2::PaginationWrapper.new([user], total_entries: 1))

    post :requesters, construct_params(term: user.email.split('@').first)

    res_body = parse_response(@response.body).map { |item| item['id'] }
    assert_includes res_body, user.id
    assert_response 200
    SearchService::QueryHandler.any_instance.unstub(:query_results)
  end

  def test_requester_with_email_domain
    user = add_new_user(@account, email: 'test-requester.for_es@freshpo.com')
    sleep ES_DELAY_TIME # Delaying for sidekiq to send to ES
    Search::V2::QueryHandler.any_instance.stubs(:query_results).returns(Search::V2::PaginationWrapper.new([user], total_entries: 1))

    post :requesters, construct_params(term: user.email.split('@').last)

    res_body = parse_response(@response.body).map { |item| item['id'] }
    assert_includes res_body, user.id
    assert_response 200
    SearchService::QueryHandler.any_instance.unstub(:query_results)
  end

  def test_requester_with_phone_number
    user = add_new_user_without_email(@account)
    sleep ES_DELAY_TIME # Delaying for sidekiq to send to ES
    Search::V2::QueryHandler.any_instance.stubs(:query_results).returns(Search::V2::PaginationWrapper.new([user], total_entries: 1))

    post :requesters, construct_params(term: user.phone)

    res_body = parse_response(@response.body).map { |item| item['id'] }
    assert_includes res_body, user.id
    assert_response 200
    SearchService::QueryHandler.any_instance.unstub(:query_results)
  end

  def test_requester_with_phone_number_auto_complete_off_view_contacts_privilege_on
    user = add_new_user_without_email(@account)
    sleep ES_DELAY_TIME # Delaying for sidekiq to send to ES

    @account.launch(:auto_complete_off)
    Search::V2::QueryHandler.any_instance.stubs(:query_results).returns(Search::V2::PaginationWrapper.new([user], total_entries: 1))
    post :requesters, construct_params(term: user.phone)

    res_body = parse_response(@response.body).map { |item| item['id'] }
    assert_includes res_body, user.id
    assert_response 200
    @account.rollback(:auto_complete_off)
    SearchService::QueryHandler.any_instance.unstub(:query_results)
  end

  def test_requester_with_email_auto_complete_off_view_contacts_privilege_on
    user = add_new_user_without_email(@account)
    sleep ES_DELAY_TIME # Delaying for sidekiq to send to ES

    @account.launch(:auto_complete_off)
    Search::V2::QueryHandler.any_instance.stubs(:query_results).returns(Search::V2::PaginationWrapper.new([user], total_entries: 1))
    post :requesters, construct_params(term: user.email)

    res_body = parse_response(@response.body).map { |item| item['id'] }
    assert_includes res_body, user.id
    assert_response 200
    @account.rollback(:auto_complete_off)
    SearchService::QueryHandler.any_instance.unstub(:query_results)
  end

  def test_requester_with_partial_email_auto_complete_off_view_contacts_privilege_on
    user = add_new_user(@account, email: 'test-requester.for_es@freshpo.com')
    sleep ES_DELAY_TIME # Delaying for sidekiq to send to ES

    @account.launch(:auto_complete_off)
    Search::V2::QueryHandler.any_instance.stubs(:query_results).returns(Search::V2::PaginationWrapper.new([user], total_entries: 1))
    post :requesters, construct_params(term: user.email.split('@').first)

    res_body = parse_response(@response.body).map { |item| item['id'] }
    assert_includes res_body, user.id
    assert_response 200
    @account.rollback(:auto_complete_off)
    SearchService::QueryHandler.any_instance.unstub(:query_results)
  end

  def test_requester_with_partial_name_auto_complete_off_view_contacts_privilege_on
    user = add_new_user(@account, email: 'test-requester.for_es@freshpo.com')
    sleep ES_DELAY_TIME # Delaying for sidekiq to send to ES

    @account.launch(:auto_complete_off)
    Search::V2::QueryHandler.any_instance.stubs(:query_results).returns(Search::V2::PaginationWrapper.new([user], total_entries: 1))
    post :requesters, construct_params(term: user.name[0..5])

    res_body = parse_response(@response.body).map { |item| item['id'] }
    assert_includes res_body, user.id
    assert_response 200
    @account.rollback(:auto_complete_off)
    SearchService::QueryHandler.any_instance.unstub(:query_results)
  end

  def test_requester_with_partial_name_auto_complete_disabled
    user = add_new_user(@account, email: 'test-requester.for_es@freshpo.com')
    sleep ES_DELAY_TIME # Delaying for sidekiq to send to ES

    disable_auto_complete

    post :requesters, construct_params(term: user.name[0..5])

    res_body = parse_response(@response.body).map { |item| item['id'] }
    assert_empty res_body
    assert_response 200

    rollback_auto_complete
  end

  def test_company_autocomplete_with_complete_name
    ApiSearch::AutocompleteDecorator.any_instance.stubs(:private_api?).returns(false)
    company = create_company
    Search::V2::QueryHandler.any_instance.stubs(:query_results).returns(Search::V2::PaginationWrapper.new([company], total_entries: 1))
    get :companies, controller_params(name: company.name)
    response = parse_response(@response.body)['companies'].map { |item| item['name'] }
    assert_response 200
    assert_includes response, company.name
  ensure
    ApiSearch::AutocompleteDecorator.any_instance.unstub(:private_api?)
    Search::V2::QueryHandler.any_instance.unstub(:query_results)
  end

  def test_company_autocomplete_with_partial_name
    ApiSearch::AutocompleteDecorator.any_instance.stubs(:private_api?).returns(false)
    company = create_company
    Search::V2::QueryHandler.any_instance.stubs(:query_results).returns(Search::V2::PaginationWrapper.new([company], total_entries: 1))
    get :companies, controller_params(name: company.name[0..3])
    response = parse_response(@response.body)['companies'].map { |item| item['name'] }
    assert_response 200
    assert_includes response, company.name
  ensure
    ApiSearch::AutocompleteDecorator.any_instance.unstub(:private_api?)
    Search::V2::QueryHandler.any_instance.unstub(:query_results)
  end

  def test_company_autcomplete_with_random_name
    ApiSearch::AutocompleteDecorator.any_instance.stubs(:private_api?).returns(false)
    get :companies, controller_params(name: Faker::Name.name)
    response = parse_response(@response.body)['companies']
    assert_response 200
    assert_empty response
  ensure
    ApiSearch::AutocompleteDecorator.any_instance.unstub(:private_api?)
  end

  def test_company_autocomplete_with_nil_name
    get :companies, controller_params(name: nil)
    assert_response 400
    match_json([bad_request_error_pattern('name', :blank, code: :invalid_value)])
  end

  def test_company_autocomplete_private_api
    ApiSearch::AutocompleteDecorator.any_instance.stubs(:private_api?).returns(true)
    get :companies, controller_params(name: Faker::Name.name)
    response = parse_response(@response.body)['companies']
    assert_response 200
    assert_empty response
  end

  def test_companies_search_autocomplete_private_api
    company = create_company
    Search::V2::QueryHandler.any_instance.stubs(:query_results).returns(Search::V2::PaginationWrapper.new([company], total_entries: 1))
    post :companies_search, controller_params(name: company.name[0..3])
    response = parse_response(@response.body).map { |item| item['value'] }
    assert_response 200
    assert_includes response, company.name
  end

  def test_agents_autocomplete_with_complete_name
    agent = add_test_agent(@account)
    sleep ES_DELAY_TIME # Delaying for sidekiq to send to ES
    Search::V2::QueryHandler.any_instance.stubs(:query_results).returns(Search::V2::PaginationWrapper.new([agent], total_entries: 1))
    post :agents, construct_params(term: agent.name)
    response = parse_response(@response.body).map { |item| item['value'] }
    assert_response 200
    assert_includes response, agent.name
  ensure
    Search::V2::QueryHandler.any_instance.unstub(:query_results)
  end

  def test_agents_autocomplete_with_partial_name
    agent = add_test_agent(@account)
    sleep ES_DELAY_TIME # Delaying for sidekiq to send to ES
    Search::V2::QueryHandler.any_instance.stubs(:query_results).returns(Search::V2::PaginationWrapper.new([agent], total_entries: 1))
    post :agents, construct_params(term: agent.name[0..3])
    response = parse_response(@response.body).map { |item| item['value'] }
    assert_response 200
    assert_includes response, agent.name
  ensure
    Search::V2::QueryHandler.any_instance.unstub(:query_results)
  end

  def test_agents_autocomplete_with_query_param
    agent = add_test_agent(@account)
    group = create_group_with_agents(@account, agent_list: [agent.id])
    sleep ES_DELAY_TIME # Delaying for sidekiq to send to ES
    Search::V2::QueryHandler.any_instance.stubs(:query_results).returns(Search::V2::PaginationWrapper.new([agent], total_entries: 1))
    post :agents, construct_params(version: 'private', term: agent.name[0..3], query: "agent_type: #{agent.agent.agent_type} AND group_ids: #{group.id}")
    response = parse_response(@response.body).map { |item| item['value'] }
    assert_response 200
    assert_includes response, agent.name
  ensure
    Search::V2::QueryHandler.any_instance.unstub(:query_results)
  end

  def test_agents_autocomplate_with_include_param
    agent = @account.account_managers.first
    Search::V2::QueryHandler.any_instance.stubs(:query_results).returns(Search::V2::PaginationWrapper.new([agent], total_entries: 1))
    post :agents, construct_params(version: 'private', term: agent.name[0..3], include: 'roles')
    response = parse_response(@response.body)
    assert_response 200
    assert_equal response.first.deep_symbolize_keys[:roles], (agent.roles.map { |role| { id: role.id, name: role.name } })
  ensure
    Search::V2::QueryHandler.any_instance.unstub(:query_results)
  end

  def test_agents_autocomplete_without_include_param
    agent = @account.account_managers.first
    Search::V2::QueryHandler.any_instance.stubs(:query_results).returns(Search::V2::PaginationWrapper.new([agent], total_entries: 1))
    post :agents, construct_params(version: 'private', term: agent.name[0..3])
    response = parse_response(@response.body)
    assert_response 200
    assert_equal response.first.deep_symbolize_keys[:roles] == agent.roles.map { |role| { id: role.id, name: role.name } }, false
  ensure
    Search::V2::QueryHandler.any_instance.unstub(:query_results)
  end

  def test_agents_autocomplate_with_invalid_include_param
    agent = @account.account_managers.first
    Search::V2::QueryHandler.any_instance.stubs(:query_results).returns(Search::V2::PaginationWrapper.new([agent], total_entries: 1))
    post :agents, construct_params(version: 'private', term: agent.name[0..3], include: 'rolestest')
    assert_response 400
  ensure
    Search::V2::QueryHandler.any_instance.unstub(:query_results)
  end

  def test_agents_autocomplete_with_invalid_search_term
    agent = @account.all_agents.first.user
    Search::V2::QueryHandler.any_instance.stubs(:query_results).returns(Search::V2::PaginationWrapper.new([agent], total_entries: 1))
    post :agents, construct_params(version: 'private', name: agent.name[0..3])
    assert_response 400
  ensure
    Search::V2::QueryHandler.any_instance.unstub(:query_results)
  end

  def test_agents_autocomplete_with_invalid_page_value
    agent = @account.all_agents.first.user
    Search::V2::QueryHandler.any_instance.stubs(:query_results).returns(Search::V2::PaginationWrapper.new([agent], total_entries: 1))
    post :agents, construct_params(version: 'private', term: agent.name[0..3], per_page: 'test')
    assert_response 400
  ensure
    Search::V2::QueryHandler.any_instance.unstub(:query_results)
  end

  def test_agents_autocomplete_with_valid_page_invalid_limit
    agent = @account.all_agents.first.user
    Search::V2::QueryHandler.any_instance.stubs(:query_results).returns(Search::V2::PaginationWrapper.new([agent], total_entries: 1))
    post :agents, construct_params(version: 'private', term: agent.name[0..3], page: 1, limit: 0)
    assert_response 400
  ensure
    Search::V2::QueryHandler.any_instance.unstub(:query_results)
  end

  def test_agents_autocomplete_with_valid_page_and_max_matches
    agent = @account.all_agents.first.user
    Search::V2::QueryHandler.any_instance.stubs(:query_results).returns(Search::V2::PaginationWrapper.new([agent], total_entries: 1))
    post :agents, construct_params(version: 'private', term: agent.name[0..3], page: 1, max_matches: 5)
    assert_response 200
  ensure
    Search::V2::QueryHandler.any_instance.unstub(:query_results)
  end

  def test_agents_autocomplete_with_invalid_name
    post :agents, construct_params(term: Faker::Name.name)
    response = parse_response(@response.body)
    assert_response 200
    assert_empty response
  end

  def test_tags_autocomplete_with_complete_name
    tag = create_tag(@account)
    sleep ES_DELAY_TIME # Delaying for sidekiq to send to ES
    Search::V2::QueryHandler.any_instance.stubs(:query_results).returns(Search::V2::PaginationWrapper.new([tag], total_entries: 1))
    post :tags, construct_params(term: tag.name)
    response = parse_response(@response.body).map { |item| item['value'] }
    assert_response 200
    assert_includes response, tag.name
  ensure
    Search::V2::QueryHandler.any_instance.unstub(:query_results)
  end

  def test_tags_autocomplete_with_partial_name
    tag = create_tag(@account)
    sleep ES_DELAY_TIME # Delaying for sidekiq to send to ES
    Search::V2::QueryHandler.any_instance.stubs(:query_results).returns(Search::V2::PaginationWrapper.new([tag], total_entries: 1))
    post :tags, construct_params(term: tag.name[0..3])
    response = parse_response(@response.body).map { |item| item['value'] }
    assert_response 200
    assert_includes response, tag.name
  ensure
    Search::V2::QueryHandler.any_instance.unstub(:query_results)
  end

  def test_tags_autocomplete_with_invalid_name
    post :tags, construct_params(term: Faker::Name.name)
    response = parse_response(@response.body)
    assert_response 200
    assert_empty response
  end

  private

    def disable_auto_complete
      remove_privilege(User.current, :view_contacts)
      @account.launch(:auto_complete_off)
    end

    def rollback_auto_complete
      add_privilege(User.current, :view_contacts)
      @account.rollback(:auto_complete_off)
    end
end
