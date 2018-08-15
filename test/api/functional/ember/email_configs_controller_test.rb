require_relative '../../test_helper'
class Ember::EmailConfigsControllerTest < ActionController::TestCase
  include EmailConfigsTestHelper

  def wrap_cname(params)
    { email_config: params }
  end

  def test_index
    maxCount = ApiConstants::EMAIL_CONFIG_PER_PAGE
    20.times { create_email_config(active: 'false') }
    maxCount.times { create_email_config(active: 'true') }
    get :index, controller_params(version: 'private')
    assert_response 200
    response = parse_response @response.body
    assert_equal maxCount, response.size
    pattern = []
    Account.current.all_email_configs.reorder('primary_role DESC').where(active: true).limit(maxCount).each do |ec|
      pattern << email_config_pattern(ec)
    end
    match_json(pattern.ordered!)
  end

  def test_search_with_complete_name
    email_config = create_email_config({active: 'true', name: "nametester"}) 
    post :search, controller_params(version: 'private', term: 'nametester')
    res_body = parse_response(@response.body).map{|item| item['name']}
    assert_match /#{email_config.name}/, res_body.first
  end

  def test_search_with_complete_email
    email_config = create_email_config({active: 'true', email: "emailtester@#{@account.full_domain}"}) 
    post :search, controller_params(version: 'private', term: "emailtester@#{@account.full_domain}")
    res_body = parse_response(@response.body).map{|item| item['to_email']}
    assert_match /#{email_config.to_email}/, res_body.first
  end

  def test_search_with_partial_name
    email_config = create_email_config({active: 'true', name: "partnametester"}) 
    post :search, controller_params(version: 'private', term: 'partn')
    res_body = parse_response(@response.body).map{|item| item['name']}
    assert_match /#{email_config.name}/, res_body.first
  end

  def test_search_with_partial_email
    email_config = create_email_config({active: 'true', email: "partemailtester@#{@account.full_domain}"}) 
    post :search, controller_params(version: 'private', term: 'partemailtester@')
    res_body = parse_response(@response.body).map{|item| item['to_email']}
    assert_match /#{email_config.to_email}/, res_body.first
  end

  def test_search_with_invalid_params
    10.times { create_email_config(active: 'false') }
    email_config = create_email_config({active: 'true', email: "invalidparamtester@#{@account.full_domain}"}) 
    post :search, controller_params(version: 'private', search_term: 'tester') #invalid param key
    assert_response 400
  end
end
