require_relative '../test_helper'

class Search::V2::AutocompleteControllerTest < ActionController::TestCase

  ########################
  # Requester test cases #
  ########################

  def test_requester_with_fb_id
    user = add_new_user_with_fb_id(@account)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    get :requesters, :q => user.fb_profile_id

    res_body = parsed_attr(response.body, 'id')
    assert_not_includes res_body, user.id
  end

  def test_requester_with_twitter_id
    user = add_new_user_with_twitter_id(@account)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    get :requesters, :q => user.twitter_id

    res_body = parsed_attr(response.body, 'id')
    assert_not_includes res_body, user.id
  end

  def test_requester_with_complete_agent_name
    user = add_test_agent(@account)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    get :requesters, :q => user.name

    res_body = parsed_attr(response.body, 'user_id')
    assert_not_includes res_body, user.id
  end

  def test_requester_with_partial_agent_name
    user = add_test_agent(@account)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    get :requesters, :q => user.name[0..10]

    res_body = parsed_attr(response.body, 'user_id')
    assert_not_includes res_body, user.id
  end

  def test_requester_with_complete_agent_email
    user = add_test_agent(@account)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    get :requesters, :q => user.email

    res_body = parsed_attr(response.body, 'user_id')
    assert_not_includes res_body, user.id
  end

  def test_requester_with_partial_agent_email
    user = add_test_agent(@account)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    get :requesters, :q => user.email.split('@').first

    res_body = parsed_attr(response.body, 'user_id')
    assert_not_includes res_body, user.id
  end

  def test_requester_with_agent_email_domain
    user = add_test_agent(@account)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    get :requesters, :q => user.email.split('@').last

    res_body = parsed_attr(response.body, 'user_id')
    assert_not_includes res_body, user.id
  end

  ####################
  # Agent test cases #
  ####################

  def test_agent_with_complete_requester_name
    user = add_new_user(@account, { email: 'test-requester.for_es@freshpo.com' })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    get :agents, :q => user.name

    res_body = parsed_attr(response.body, 'user_id')
    assert_not_includes res_body, user.id
  end

  def test_agent_with_partial_requester_name
    user = add_new_user(@account, { email: 'test-requester.for_es@freshpo.com' })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    get :agents, :q => user.name[0..10]

    res_body = parsed_attr(response.body, 'user_id')
    assert_not_includes res_body, user.id
  end

  def test_agent_with_complete_requester_email
    user = add_new_user(@account, { email: 'test-requester.for_es@freshpo.com' })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    get :agents, :q => user.email

    res_body = parsed_attr(response.body, 'user_id')
    assert_not_includes res_body, user.id
  end

  def test_agent_with_partial_requester_email
    user = add_new_user(@account, { email: 'test-requester.for_es@freshpo.com' })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    get :agents, :q => user.email.split('@').first

    res_body = parsed_attr(response.body, 'user_id')
    assert_not_includes res_body, user.id
  end

  def test_agent_with_requester_email_domain
    user = add_new_user(@account, { email: 'test-requester.for_es@freshpo.com' })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    get :agents, :q => user.email.split('@').last

    res_body = parsed_attr(response.body, 'user_id')
    assert_not_includes res_body, user.id
  end

  def test_agent_with_requester_phone
    user = add_new_user_without_email(@account)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    get :agents, :q => user.phone

    res_body = parsed_attr(response.body, 'user_id')
    assert_not_includes res_body, user.id
  end

  ######################
  # Company test cases #
  ######################

  def test_company_with_description
    company = create_company
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :companies, :q => company.description

    res_body = parsed_attr(response.body, 'id')
    assert_not_includes res_body, company.id
  end

  def test_company_with_note
    company = create_company
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :companies, :q => company.note

    res_body = parsed_attr(response.body, 'id')
    assert_not_includes res_body, company.id
  end

  def test_company_with_domain
    company = create_company
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :companies, :q => company.domains.split(',').first

    res_body = parsed_attr(response.body, 'id')
    assert_not_includes res_body, company.id
  end
end