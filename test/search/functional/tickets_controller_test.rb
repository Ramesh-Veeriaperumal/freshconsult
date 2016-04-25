require_relative '../test_helper'

class Search::V2::TicketsControllerTest < ActionController::TestCase

  def test_ticket_by_complete_display_id
    ticket = create_ticket
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :index, :search_field => 'display_id', :term => ticket.display_id

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, ticket.id
  end

  def test_ticket_by_partial_display_id
    ticket = create_ticket({ display_id: 212200 })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :index, :search_field => 'display_id', :term => '212'

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, ticket.id
  end

  def test_ticket_by_complete_subject
    ticket = create_ticket
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :index, :search_field => 'subject', :term => ticket.subject

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, ticket.id
  end

  def test_ticket_by_partial_subject
    ticket = create_ticket
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :index, :search_field => 'subject', :term => ticket.subject[0..10]

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, ticket.id
  end

  def test_ticket_by_requester_name
    requester = add_new_user(@account)
    ticket = create_ticket({ requester_id: requester.id })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :index, :search_field => 'requester', :term => requester.name

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, ticket.id
  end

  def test_ticket_by_requester_email
    requester = add_new_user(@account)
    ticket = create_ticket({ requester_id: requester.id })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :index, :search_field => 'requester', :term => requester.email

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, ticket.id
  end

  def test_ticket_by_requester_phone
    requester = add_new_user_without_email(@account)
    ticket = create_ticket({ requester_id: requester.id })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :index, :search_field => 'requester', :term => requester.phone

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, ticket.id
  end
end