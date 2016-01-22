require_relative '../test_helper'

class Search::V2::AutocompleteControllerTest < ActionController::TestCase

  ########################
  # Requester test cases #
  ########################

  def test_requester_with_complete_name
    user = add_new_user(@account, { email: 'test-requester.for_es@freshpo.com' })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    get :requesters, { q: user.name }

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, user.id
  end

  def test_requester_with_partial_name
    user = add_new_user(@account, { email: 'test-requester.for_es@freshpo.com' })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    get :requesters, :q => user.name[0..10]

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, user.id
  end

  def test_requester_with_complete_email
    user = add_new_user(@account, { email: 'test-requester.for_es@freshpo.com' })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    get :requesters, :q => user.email

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, user.id
  end

  def test_requester_with_partial_email
    user = add_new_user(@account, { email: 'test-requester.for_es@freshpo.com' })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    get :requesters, :q => user.email.split('@').first

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, user.id
  end

  def test_requester_with_email_domain
    user = add_new_user(@account, { email: 'test-requester.for_es@freshpo.com' })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    get :requesters, :q => user.email.split('@').last

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, user.id
  end

  def test_requester_with_phone_number
    user = add_new_user_without_email(@account)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    get :requesters, :q => user.phone

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, user.id
  end

  ####################
  # Agent test cases #
  ####################

  def test_agent_with_complete_name
    user = add_test_agent(@account)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    get :agents, :q => user.name

    res_body = parsed_attr(response.body, 'user_id')
    assert_includes res_body, user.id
  end

  def test_agent_with_partial_name
    user = add_test_agent(@account)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    get :agents, :q => user.name[0..10]

    res_body = parsed_attr(response.body, 'user_id')
    assert_includes res_body, user.id
  end

  def test_agent_with_complete_email
    user = add_test_agent(@account)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    get :agents, :q => user.email

    res_body = parsed_attr(response.body, 'user_id')
    assert_includes res_body, user.id
  end

  def test_agent_with_partial_email
    user = add_test_agent(@account)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    get :agents, :q => user.email.split('@').first

    res_body = parsed_attr(response.body, 'user_id')
    assert_includes res_body, user.id
  end

  def test_agent_with_email_domain
    user = add_test_agent(@account)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    get :agents, :q => user.email.split('@').last

    res_body = parsed_attr(response.body, 'user_id')
    assert_includes res_body, user.id
  end

  ######################
  # Company test cases #
  ######################

  def test_company_with_complete_name
    company = create_company
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :companies, :q => company.name

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, company.id
  end

  def test_company_with_partial_name
    company = create_company
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :companies, :q => company.name[0..10]

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, company.id
  end

  ######################
  # Tag test cases #
  ######################

  def test_tag_with_complete_name
    tag = @account.tags.create(name: 'es-v2.testing1')
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :tags, :q => tag.name

    res_body = parsed_attr(response.body, 'value')
    assert_includes res_body, tag.name
  end

  def test_tag_with_partial_name
    tag = @account.tags.create(name: 'es-v2.testing2')
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :tags, :q => tag.name[0..5]

    res_body = parsed_attr(response.body, 'value')
    assert_includes res_body, tag.name
  end
end