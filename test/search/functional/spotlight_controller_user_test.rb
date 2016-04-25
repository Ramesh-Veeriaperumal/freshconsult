require_relative '../test_helper'

class Search::V2::SpotlightControllerTest < ActionController::TestCase

  def test_user_by_complete_name
    user = add_new_user(@account, { name: Faker::Name.name })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :customers, term: user.name

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, user.id
  end

  def test_user_by_partial_name
    user = add_new_user(@account, { name: Faker::Name.name })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :customers, term: user.name

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, user.id
  end

  def test_user_by_complete_primary_email
    user = add_user_with_multiple_emails(@account, 2)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :customers, term: user.email

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, user.id
  end

  def test_user_by_partial_primary_email
    user = add_user_with_multiple_emails(@account, 2)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :customers, term: user.email.split('@').first

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, user.id
  end

  def test_user_by_primary_email_domain
    user = add_user_with_multiple_emails(@account, 2)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :customers, term: user.email.split('@').last

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, user.id
  end

  def test_user_by_complete_secondary_email
    user = add_user_with_multiple_emails(@account, 2)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :customers, term: user.user_emails.where(primary_role: false).first.email

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, user.id
  end

  def test_user_by_partial_secondary_email
    user = add_user_with_multiple_emails(@account, 2)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :customers, term: user.user_emails.where(primary_role: false).first.email.split('@').first

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, user.id
  end

  def test_user_by_secondary_email_domain
    user = add_user_with_multiple_emails(@account, 2)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :customers, term: user.user_emails.where(primary_role: false).first.email.split('@').last

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, user.id
  end

  def test_user_by_complete_description
    user = add_new_user(@account)
    user.update_attribute(:description, Faker::Lorem.sentence)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :customers, term: user.description

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, user.id
  end

  def test_user_by_partial_description
    user = add_new_user(@account)
    user.update_attribute(:description, Faker::Lorem.sentence)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :customers, term: user.description[0..10]

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, user.id
  end

  def test_user_by_complete_job_title
    user = add_new_user(@account)
    user.update_attribute(:job_title, 'Senior Product Developer')
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :customers, term: user.job_title

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, user.id
  end

  def test_user_by_partial_job_title
    user = add_new_user(@account)
    user.update_attribute(:job_title, 'Senior Account Manager')
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :customers, term: 'Acc Man'

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, user.id
  end

  def test_user_by_complete_phone
    user = add_new_user_without_email(@account)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :customers, term: user.phone

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, user.id
  end

  def test_user_by_partial_phone
    user = add_new_user_without_email(@account)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :customers, term: user.phone[0..5]

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, user.id
  end

  def test_user_by_complete_mobile
    user = add_new_user_without_email(@account)
    user.update_attribute(:mobile, Faker::PhoneNumber.phone_number)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :customers, term: user.mobile

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, user.id
  end

  def test_user_by_partial_mobile
    user = add_new_user_without_email(@account)
    user.update_attribute(:mobile, Faker::PhoneNumber.phone_number)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :customers, term: user.mobile[0..5]

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, user.id
  end

  def test_user_by_complete_company_name
    company = create_company
    user = add_new_user(@account, { customer_id: company.id })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :customers, term: user.company.name

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, user.id
  end

  def test_user_by_partial_company_name
    company = create_company
    user = add_new_user(@account, { customer_id: company.id })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :customers, term: user.company.name[0..5]

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, user.id
  end

  def test_user_by_complete_twitter_id
    user = add_new_user_with_twitter_id(@account)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :customers, term: user.twitter_id

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, user.id
  end

  def test_user_by_partial_twitter_id
    user = add_new_user_with_twitter_id(@account)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :customers, term: user.twitter_id[0..3]

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, user.id
  end

  def test_user_by_complete_fb_profile_id
    user = add_new_user_with_fb_id(@account)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :customers, term: user.fb_profile_id

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, user.id
  end

  def test_user_by_partial_fb_profile_id
    user = add_new_user_with_fb_id(@account)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :customers, term: user.fb_profile_id[0..3]

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, user.id
  end

  # def test_user_by_complete_line_text
  #   create_contact_field(cf_params({ type: 'text', field_type: 'custom_text', label: 'Country' }))
  #   user = add_new_user(@account)
  #   cf_val = Faker::Address.country
  #   user.update_attributes(custom_field: { cf_country: cf_val })
  #   sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

  #   get :customers, term: cf_val

  #   res_body = parsed_attr(response.body, 'id')
  #   assert_includes res_body, user.id
  # end

  # def test_user_by_partial_line_text
  #   create_contact_field(cf_params({ type: 'text', field_type: 'custom_text', label: 'Country' }))
  #   user = add_new_user(@account)
  #   cf_val = Faker::Address.country
  #   user.update_attributes(custom_field: { cf_country: cf_val })
  #   sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

  #   get :customers, term: cf_val[0..2]

  #   res_body = parsed_attr(response.body, 'id')
  #   assert_includes res_body, user.id
  # end

  # def test_user_by_complete_para_text
  #   create_contact_field(cf_params({ type: 'paragraph', field_type: 'custom_paragraph', label: 'Teams' }))
  #   user = add_new_user(@account)
  #   cf_val = 3.times.collect { Faker::Team.name }
  #   user.update_attributes(custom_field: { cf_teams: cf_val.join(',') })
  #   sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

  #   get :customers, term: cf_val.join(' ')

  #   res_body = parsed_attr(response.body, 'id')
  #   assert_includes res_body, user.id
  # end

  # def test_user_by_partial_para_text
  #   create_contact_field(cf_params({ type: 'paragraph', field_type: 'custom_paragraph', label: 'Teams' }))
  #   user = add_new_user(@account)
  #   cf_val = 3.times.collect { Faker::Team.name }
  #   user.update_attributes(custom_field: { cf_teams: cf_val.join(',') })
  #   sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

  #   get :customers, term: cf_val[Random.rand(0..2)][0..3]

  #   res_body = parsed_attr(response.body, 'id')
  #   assert_includes res_body, user.id
  # end

end