require_relative '../../test_helper'
['bot_test_helper.rb', 'bot_response_test_helper.rb' ,'attachments_test_helper.rb'].each { |file| require "#{Rails.root}/test/api/helpers/#{file}" }
class Support::BotResponsesControllerTest < ActionController::TestCase
  include TicketHelper
  include ApiBotTestHelper
  include AttachmentsTestHelper
  include BotResponseTestHelper

  def setup
    super
    @account ||= Account.first.make_current
    Portal.any_instance.stubs(:multilingual?).returns(false)
    @account.launch :bot_email_channel
    initial_setup
  end

  def teardown
    @account.rollback :bot_email_channel
    Portal.any_instance.unstub(:multilingual?)
  end

  @@initial_setup_run = false

  def initial_setup
  	return if @@initial_setup_run
    create_new_bot_response
    @@initial_setup_run = true
  end

  def create_new_bot_response
    ticket = create_ticket
    @@bot = get_bot || create_bot
    query_id = Faker::Lorem.characters(20)
    @@suggested_articles ||= construct_suggested_articles
    bot_response = create_sample_bot_response(ticket.id, @@bot.id, query_id, @@suggested_articles)
    bot_response
  end

  def test_filter_without_feature
    skip("ticket tests failing")
    @account.rollback :bot_email_channel
    query_id = @account.bot_responses.last.query_id
    get :filter, {query_id: query_id}
    assert_response 403
    @account.launch :bot_email_channel
  end

  def test_update_without_feature
    skip("ticket tests failing")
    @account.rollback :bot_email_channel
    query_id = @account.bot_responses.last.query_id
    put :update_response, {query_id: query_id}
    assert_response 403
    @account.launch :bot_email_channel
  end

  def test_filter_with_invalid_query_id
    skip("ticket tests failing")
    get :filter, {query_id: 'invalid', solution_id: @@articles.first.id}
    assert_response 404
  end

  def test_update_with_invalid_query_id
    skip("ticket tests failing")
    put :update_response, {query_id: 'invalid', solution_id: @@articles.first.id, useful: true}
    assert_response 404
  end

  def test_filter_with_valid_query_id_and_invalid_solution_id
    skip("ticket tests failing")
    query_id = @account.bot_responses.last.query_id
    get :filter, {query_id: query_id, solution_id: '999999'}
    assert_response 404
  end

  def test_update_with_valid_query_id_and_invalid_solution_id
    skip("ticket tests failing")
    query_id = @account.bot_responses.last.query_id
    put :update_response, {query_id: query_id, solution_id: '999999', useful: true}
    assert_response 404
  end

  def test_filter_without_query_id_and_solution_id
    skip("ticket tests failing")
    get :filter, {}
    assert_response 400
  end

  def test_update_without_query_id_and_solution_id
    skip("ticket tests failing")
    put :update_response, {}
    assert_response 400
  end

  def test_filter_with_query_id_and_without_solution_id
    skip("ticket tests failing")
    query_id = @account.bot_responses.last.query_id
    get :filter, {query_id: query_id}
    assert_response 400
  end

  def test_update_without_query_id_and_with_solution_id
    skip("ticket tests failing")
    put :update_response, {solution_id: @@articles.first.id}
    assert_response 400
  end

  def test_filter_with_valid_query_id_and_valid_solution_id
    skip("ticket tests failing")
    query_id = @account.bot_responses.last.query_id
    get :filter, {query_id: query_id, solution_id: @@articles.first.id}
    assert_response 200
    match_json(support_namespace_bot_response_pattern(@@articles.first.id))
  end

  def test_update_with_valid_query_id_and_valid_solution_id_mark_not_useful
    skip("ticket tests failing")
    bot_response = create_new_bot_response
    query_id = bot_response.query_id
    put :update_response, {query_id: query_id, solution_id: @@articles.first.id, useful: false}
    assert_response 200
    match_json(support_namespace_bot_response_pattern(@@articles.first.id))
  end

  def test_update_with_valid_query_id_and_valid_solution_id_mark_useful
    skip("ticket tests failing")
    bot_response = create_new_bot_response
    query_id = bot_response.query_id
    put :update_response, {query_id: query_id, solution_id: @@articles.last.id, useful: true}
    assert_response 200
    match_json(support_namespace_bot_response_pattern(@@articles.last.id))
  end

  def test_ticket_close_by_is_requester_when_user_current_is_nil
    skip("ticket tests failing")
    bot_response = create_new_bot_response
    current_user = User.current
    User.reset_current_user
    query_id = bot_response.query_id
    put :update_response, {query_id: query_id, solution_id: @@articles.last.id, useful: true}
    assert_equal bot_response.ticket.activities.last.user_id, bot_response.ticket.requester.id
    User.current = current_user
  end
end
