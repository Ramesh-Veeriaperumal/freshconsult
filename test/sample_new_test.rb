# use_transactional_fixtures is enabled in test_helper - any changes done in DB will be rolled back at the end of the test
# flush_all redis keys is enabled in test helper

###### steps to follow when running test in local ######
# run 'rake db:bootstrap RAILS_ENV=test' > to load fixtures in DB
# run 'rake db:test_clean_setup' > to clean all non-meta data from DB - Refer test/clean_db.sh
# finally, we have one sample account & one admin user (sample@freshdesk.com)

# follow naming convention for test file - should end with _new_test.rb

require_relative 'api/api_test_helper'
require Rails.root.join('test', 'api', 'helpers', 'tickets_test_helper.rb')

class TicketsControllerTest < ActionController::TestCase
  include ApiTicketsTestHelper

  def setup
    super
  end

  def wrap_cname(params = {})
    { ticket: params }
  end

  def ticket_params_hash
    cc_emails = [Faker::Internet.email, Faker::Internet.email, "\"#{Faker::Name.name}\" <#{Faker::Internet.email}>"]
    subject = Faker::Lorem.words(10).join(' ')
    description = Faker::Lorem.paragraph
    email = Faker::Internet.email
    tags = [Faker::Name.name, Faker::Name.name]
    @create_group ||= create_group_with_agents(@account, agent_list: [@agent.id])
    params_hash = { email: email, cc_emails: cc_emails, description: description, subject: subject,
                    priority: 2, status: 3, type: 'Problem', responder_id: @agent.id, source: 1, tags: tags,
                    group_id: @create_group.id }
    params_hash
  end

  # show
  # test will fail as there are no tickets in helpdesk_tickets table at the start. Refer test_sample_1 for the correct way
  def wrong_test_sample_1
    get :show, controller_params(id: Helpdesk::Ticket.first.display_id)
    assert_response 200
  end

  def test_sample_1
    ticket = create_ticket(ticket_params_hash)
    get :show, controller_params(id: ticket.display_id)

    assert_response 200
  end

  # create
  # changes done to DB in this test will be rolled back at the end of the test.
  def test_sample_2
    params = ticket_params_hash.merge(custom_fields: {}, description: '<b>test</b>')
    post :create, construct_params({}, params)

    result = parse_response(@response.body)
    assert_response 201
    assert_equal "http://#{@request.host}/api/v2/tickets/#{result['id']}", response.headers['Location']
    assert_equal 'test', Helpdesk::Ticket.first.description
    assert_equal 1, Helpdesk::Ticket.count
  end

  # update
  # previous test transaction is not saved in DB - hence this test will fail. Refer test_sample_3 for correct way
  def wrong_test_sample_3
    ticket = Helpdesk::Ticket.first # Will be nil
    update_params = { type: 'Question' }
    put :update, construct_params({ id: ticket.display_id }, update_params)

    assert_response 200
    response = parse_response @response.body
    assert_equal 'Question', response['type']
  end

  def test_sample_3
    ticket = create_ticket(ticket_params_hash)
    update_params = { type: 'Question' }
    put :update, construct_params({ id: ticket.display_id }, update_params)

    assert_response 200
    response = parse_response @response.body
    assert_equal 'Question', response['type']
  end

  # index
  # create 3 tickets and check 3 ticket is shown in index
  def test_sample_4
    3.times do |i|
      params_hash = {
        email: Faker::Internet.email,
        cc_emails: [Faker::Internet.email, Faker::Internet.email, "\"#{Faker::Name.name}\" <#{Faker::Internet.email}>"],
        description: Faker::Lorem.paragraph,
        subject: Faker::Lorem.words(10).join(' '),
        priority: [1, 2, 3, 4].sample,
        status: [2, 3, 4, 5].sample,
        type: 'Incident',
        responder_id: @agent.id,
        source: 1,
        tags: [Faker::Name.name, Faker::Name.name]
      }
      create_ticket(params_hash)
    end

    get :index, controller_params(per_page: 30)

    assert_response 200
    assert_equal 3, Helpdesk::Ticket.count
  end

  # storing key in redis
  def test_sample_5
    $redis_others.set('test', 'test')

    assert_equal 'test', $redis_others.get('test')
  end

  # fetching key from redis
  # test will fail as flush_all redis keys is enabled in test helper file
  def wrong_test_sample_5
    assert_equal 'test', $redis_others.get('test')
  end
end
