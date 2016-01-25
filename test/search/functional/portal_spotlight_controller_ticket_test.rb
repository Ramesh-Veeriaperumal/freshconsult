require_relative '../test_helper'

class Support::SearchV2::SpotlightControllerTest < ActionController::TestCase

  def setup
    super
    @contact = FactoryGirl.build(:user, :account => @account, :email => Faker::Internet.email, :user_role => 3)
    log_in(@contact)
  end

  def test_ticket_by_complete_display_id
    ticket = create_ticket({ requester_id: @contact.id })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    xhr :get, :tickets, term: ticket.display_id

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/tickets/#{ticket.display_id}"
  end

  def test_ticket_by_partial_display_id
    ticket = create_ticket({ requester_id: @contact.id, display_id: 315200 })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    xhr :get, :tickets, term: '315'

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/tickets/#{ticket.display_id}"
  end

  def test_ticket_by_complete_subject
    ticket = create_ticket({ requester_id: @contact.id })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    xhr :get, :tickets, term: ticket.subject

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/tickets/#{ticket.display_id}"
  end

  def test_ticket_by_partial_subject
    ticket = create_ticket({ requester_id: @contact.id })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    xhr :get, :tickets, term: ticket.subject[0..3]

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/tickets/#{ticket.display_id}"
  end

  def test_ticket_by_complete_description
    ticket = create_ticket({ requester_id: @contact.id })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    xhr :get, :tickets, term: ticket.description

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/tickets/#{ticket.display_id}"
  end

  def test_ticket_by_partial_description
    ticket = create_ticket({ requester_id: @contact.id })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    xhr :get, :tickets, term: ticket.description[0..3]

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/tickets/#{ticket.display_id}"
  end

  def test_ticket_by_complete_to_email
    ticket = create_ticket({ requester_id: @contact.id })
    ticket.to_emails = [Faker::Internet.email]
    ticket.save
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    xhr :get, :tickets, term: ticket.to_emails.first

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/tickets/#{ticket.display_id}"
  end

  def test_ticket_by_partial_to_email
    ticket = create_ticket({ requester_id: @contact.id })
    ticket.to_emails = [Faker::Internet.email]
    ticket.save
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    xhr :get, :tickets, term: ticket.to_emails.first.split('@').first

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/tickets/#{ticket.display_id}"
  end

  def test_ticket_by_complete_cc_email
    cc_email = [Faker::Internet.email]
    ticket = create_ticket({ requester_id: @contact.id, cc_emails: cc_email })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    xhr :get, :tickets, term: cc_email.first

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/tickets/#{ticket.display_id}"
  end

  def test_ticket_by_partial_cc_email
    cc_email = [Faker::Internet.email]
    ticket = create_ticket({ requester_id: @contact.id, cc_emails: cc_email })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    xhr :get, :tickets, term: cc_email.first[0..5]

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/tickets/#{ticket.display_id}"
  end

  def test_ticket_by_complete_fwd_email
    fwd_email = [Faker::Internet.email]
    ticket = create_ticket({ requester_id: @contact.id, fwd_emails: fwd_email })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    xhr :get, :tickets, term: fwd_email.first

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/tickets/#{ticket.display_id}"
  end

  def test_ticket_by_partial_fwd_email
    fwd_email = [Faker::Internet.email]
    ticket = create_ticket({ requester_id: @contact.id, fwd_emails: fwd_email })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    xhr :get, :tickets, term: fwd_email.first[0..5]

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/tickets/#{ticket.display_id}"
  end

  def test_ticket_by_complete_line_text
    city = Faker::Address.city
    c_field = create_custom_field('es_region','text')
    c_field.update_column(:visible_in_portal, true)
    ticket = create_ticket({ requester_id: @contact.id })
    ticket.send("es_region_#{@account.id}=", city)
    ticket.save
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    xhr :get, :tickets, term: city

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/tickets/#{ticket.display_id}"
  end

  def test_ticket_by_partial_line_text
    city = Faker::Address.city
    c_field = create_custom_field('es_region','text')
    c_field.update_column(:visible_in_portal, true)
    ticket = create_ticket({ requester_id: @contact.id })
    ticket.send("es_region_#{@account.id}=", city)
    ticket.save
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    xhr :get, :tickets, term: city[0..3]

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/tickets/#{ticket.display_id}"
  end

  def test_ticket_by_complete_para_text
    nouns = Faker::Hacker.noun
    c_field = create_custom_field('es_nouns','paragraph')
    c_field.update_column(:visible_in_portal, true)
    ticket = create_ticket({ requester_id: @contact.id })
    ticket.send("es_nouns_#{@account.id}=", nouns)
    ticket.save
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    xhr :get, :tickets, term: nouns

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/tickets/#{ticket.display_id}"
  end

  def test_ticket_by_partial_para_text
    nouns = Faker::Hacker.noun
    c_field = create_custom_field('es_nouns','paragraph')
    c_field.update_column(:visible_in_portal, true)
    ticket = create_ticket({ requester_id: @contact.id })
    ticket.send("es_nouns_#{@account.id}=", nouns)
    ticket.save
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    xhr :get, :tickets, term: nouns[0..5]

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/tickets/#{ticket.display_id}"
  end

  def test_ticket_by_complete_public_note
    dept = Faker::Commerce.department
    ticket = create_ticket({ requester_id: @contact.id })
    note = create_note({ 
                          source: Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['note'],
                          ticket_id: ticket.id,
                          user_id: @contact.id,
                          private: false,
                          body: "Report from the department of #{dept}"
                        })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    xhr :get, :tickets, term: dept

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/tickets/#{ticket.display_id}"
  end

  def test_ticket_by_partial_public_note
    dept = Faker::Commerce.department
    ticket = create_ticket({ requester_id: @contact.id })
    note = create_note({ 
                          source: Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['note'],
                          ticket_id: ticket.id,
                          user_id: @contact.id,
                          private: false,
                          body: "Report from the department of #{dept}"
                        })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    xhr :get, :tickets, term: dept[0..5]

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/tickets/#{ticket.display_id}"
  end

  def test_ticket_by_attachment_name
    ticket = create_ticket({ requester_id: @contact.id,
      attachments: { resource: fixture_file_upload('files/facebook.png', 'image/jpeg') } })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    xhr :get, :tickets, term: 'facebook'

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/tickets/#{ticket.display_id}"
  end

end