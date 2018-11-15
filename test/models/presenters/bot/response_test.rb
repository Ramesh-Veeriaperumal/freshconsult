require_relative '../../test_helper'
require Rails.root.join('test', 'api', 'helpers', 'bot_response_test_helper.rb')
class ResponseTest < ActiveSupport::TestCase
  include TicketsTestHelper
  include BotResponseTestHelper

  def setup
    super
    @account = @account.make_current
    @account.subscription.state = 'active'
    @account.subscription.save
    @account.launch(:bot_email_central_publish)
    @ticket = create_ticket(ticket_params_hash)
    @articles = construct_suggested_articles
    @query_id = UUIDTools::UUID.timestamp_create.hexdigest.to_s
    @bot = @account.main_portal.bot || create_test_email_bot({email_channel: true})
  end

  def teardown
    @account.rollback(:bot_email_central_publish)
    Account.unstub(:current)
  end

  def test_central_publish_with_launch_party_enabled
    CentralPublisher::Worker.jobs.clear
    create_sample_bot_response(@ticket.id, @bot.id, @query_id, @articles)
    assert_equal 1, CentralPublisher::Worker.jobs.size
  end

  def test_central_publish_with_launch_party_disabled
    @account.rollback(:bot_email_central_publish)
    CentralPublisher::Worker.jobs.clear
    create_sample_bot_response(@ticket.id, @bot.id, @query_id, @articles)
    assert_equal 0, CentralPublisher::Worker.jobs.size
  ensure
    @account.launch(:bot_email_central_publish)
  end

  def test_response_create_central_publish_payload
    CentralPublisher::Worker.jobs.clear
    bot_response = create_sample_bot_response(@ticket.id, @bot.id, @query_id, @articles)
    assert_equal 1, CentralPublisher::Worker.jobs.size
    payload = bot_response.central_publish_payload.to_json    
    payload.must_match_json_expression(central_publish_bot_response_pattern(bot_response))
    assoc_payload = bot_response.associations_to_publish.to_json
    assoc_payload.must_match_json_expression(central_publish_bot_response_association_pattern(bot_response))
  end

  def test_response_update_central_publish_payload
    bot_response = create_sample_bot_response(@ticket.id, @bot.id, @query_id, @articles)
    CentralPublisher::Worker.jobs.clear
    update_bot_response(bot_response)
    assert_equal 1, CentralPublisher::Worker.jobs.size
    payload = bot_response.central_publish_payload.to_json    
    payload.must_match_json_expression(central_publish_bot_response_pattern(bot_response))
    assoc_payload = bot_response.associations_to_publish.to_json
    assoc_payload.must_match_json_expression(central_publish_bot_response_association_pattern(bot_response))
    job = CentralPublisher::Worker.jobs.last
    assert_equal 'bot_response_update', job['args'][0]
    assert_equal(model_changes_for_central_pattern(bot_response), job['args'][1]['model_changes'])
  end

  def test_response_destroy_central_publish
    bot_response = create_sample_bot_response(@ticket.id, @bot.id, @query_id, @articles)
    pattern_to_match = central_publish_bot_response_destroy_pattern(bot_response)
    CentralPublisher::Worker.jobs.clear
    bot_response.destroy
    assert_equal 1, CentralPublisher::Worker.jobs.size
    job = CentralPublisher::Worker.jobs.last
    assert_equal 'bot_response_destroy', job['args'][0]
    assert_equal({}, job['args'][1]['model_changes'])
    job['args'][1]['model_properties'].must_match_json_expression(pattern_to_match)
  end

end
