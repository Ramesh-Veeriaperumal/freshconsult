require_relative '../test_helper'

class Search::V2::SpotlightControllerTest < ActionController::TestCase

  def test_company_by_complete_name
    company = create_company
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :customers, term: company.name

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, company.id
  end

  def test_company_by_partial_name
    company = create_company
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :customers, term: company.name[0..3]

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, company.id
  end

  def test_company_by_complete_note
    company = create_company
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :customers, term: company.note

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, company.id
  end

  def test_company_by_partial_note
    company = create_company
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :customers, term: company.note[0..5]

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, company.id
  end

  def test_company_by_complete_description
    company = create_company
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :customers, term: company.description

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, company.id
  end

  def test_company_by_partial_description
    company = create_company
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :customers, term: company.description[0..10]

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, company.id
  end

  # def test_company_by_complete_line_text
  #   create_company_field(company_params({ type: 'text', field_type: 'custom_text', label: 'Country' }))
  #   company = create_company
  #   cf_val = Faker::Address.country
  #   company.update_attributes(custom_field: { cf_country: cf_val })
  #   sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

  #   get :customers, term: cf_val

  #   res_body = parsed_attr(response.body, 'id')
  #   assert_includes res_body, company.id
  # end

  # def test_company_by_partial_line_text
  #   create_company_field(company_params({ type: 'text', field_type: 'custom_text', label: 'Country' }))
  #   company = create_company
  #   cf_val = Faker::Address.country
  #   company.update_attributes(custom_field: { cf_country: cf_val })
  #   sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

  #   get :customers, term: cf_val[0..2]

  #   res_body = parsed_attr(response.body, 'id')
  #   assert_includes res_body, company.id
  # end

  # def test_company_by_complete_para_text
  #   create_company_field(company_params({ type: 'paragraph', field_type: 'custom_paragraph', label: 'Teams' }))
  #   company = create_company
  #   cf_val = 3.times.collect { Faker::Team.name }
  #   company.update_attributes(custom_field: { cf_teams: cf_val.join(',') })
  #   sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

  #   get :customers, term: cf_val.join(' ')

  #   res_body = parsed_attr(response.body, 'id')
  #   assert_includes res_body, company.id
  # end

  # def test_company_by_partial_para_text
  #   create_company_field(company_params({ type: 'paragraph', field_type: 'custom_paragraph', label: 'Teams' }))
  #   company = create_company
  #   cf_val = 3.times.collect { Faker::Team.name }
  #   company.update_attributes(custom_field: { cf_teams: cf_val.join(',') })
  #   sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

  #   get :customers, term: cf_val[Random.rand(0..2)][0..3]

  #   res_body = parsed_attr(response.body, 'id')
  #   assert_includes res_body, company.id
  # end

  def test_company_by_complete_domains
    company = create_company
    domains = 3.times.collect { Faker::Internet.domain_name }
    company.update_attribute(:domains, domains.join(','))
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :customers, term: domains.first

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, company.id
  end

  def test_company_by_partial_domains
    company = create_company
    domains = 3.times.collect { Faker::Internet.domain_name }
    company.update_attribute(:domains, domains.join(','))
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :customers, term: domains.last[0..2]

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, company.id
  end

end