require_relative '../test_helper'

class Search::V2::TicketsControllerTest < ActionController::TestCase

  def test_ticket_by_display_id
    ticket = create_ticket
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :index, :search_field => 'display_id', :term => "#{ticket.display_id}#{Random.rand(0..9)}"

    res_body = parsed_attr(response.body, 'id')
    assert_not_includes res_body, ticket.id
  end

  def test_ticket_by_another_display_id
    ticket = create_ticket
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :index, :search_field => 'display_id', :term => Random.rand.to_s[2..6]

    res_body = parsed_attr(response.body, 'id')
    assert_not_includes res_body, ticket.id
  end

  def test_ticket_by_random_subject
    ticket = create_ticket
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :index, :search_field => 'subject', :term => ticket.subject.reverse

    res_body = parsed_attr(response.body, 'id')
    assert_not_includes res_body, ticket.id
  end

  def test_ticket_by_requester_name_reversed
    requester = add_new_user(@account)
    ticket = create_ticket({ requester_id: requester.id })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :index, :search_field => 'requester', :term => requester.name.reverse

    res_body = parsed_attr(response.body, 'id')
    assert_not_includes res_body, ticket.id
  end

  def test_ticket_by_requester_email_reversed
    requester = add_new_user(@account)
    ticket = create_ticket({ requester_id: requester.id })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :index, :search_field => 'requester', :term => requester.email.reverse

    res_body = parsed_attr(response.body, 'id')
    assert_not_includes res_body, ticket.id
  end

  def test_ticket_by_requester_phone_reversed
    requester = add_new_user_without_email(@account)
    ticket = create_ticket({ requester_id: requester.id })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :index, :search_field => 'requester', :term => requester.phone.reverse

    res_body = parsed_attr(response.body, 'id')
    assert_not_includes res_body, ticket.id
  end
end