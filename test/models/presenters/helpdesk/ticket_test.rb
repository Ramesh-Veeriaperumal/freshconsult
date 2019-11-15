require_relative '../../test_helper'
['ticket_fields_test_helper.rb'].each { |file| require "#{Rails.root}/test/api/helpers/#{file}" }
['note_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
['social_tickets_creation_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }

class TicketTest < ActiveSupport::TestCase
  include TicketsTestHelper
  include TicketFieldsTestHelper
  include ModelsGroupsTestHelper
  include NoteHelper
  include SocialTicketsCreationHelper

  CUSTOM_FIELDS = %w(number checkbox decimal text paragraph dropdown country state city date)
  DROPDOWN_CHOICES = ['Get Smart', 'Pursuit of Happiness', 'Armaggedon']

  def setup
    super
    before_all
  end

  @@before_all_run = false

  def before_all
    return if @@before_all_run
    @account.subscription.state = 'active'
    @account.subscription.save
    @account.launch(:ticket_central_publish)
    @account.ticket_fields.custom_fields.each(&:destroy)
    @@ticket_fields = []
    @@custom_field_names = []
    @@ticket_fields << create_dependent_custom_field(%w(test_custom_country test_custom_state test_custom_city))
    @@ticket_fields << create_custom_field_dropdown('test_custom_dropdown', DROPDOWN_CHOICES)
    CUSTOM_FIELDS.each do |custom_field|
      next if %w(dropdown country state city).include?(custom_field)
      @@ticket_fields << create_custom_field("test_custom_#{custom_field}", custom_field)
    end
    @@before_all_run = true
  end

  def test_central_publish_with_launch_party_disabled
    Account.current.rollback(:ticket_central_publish)
    CentralPublishWorker::ActiveTicketWorker.jobs.clear
    t = create_ticket(ticket_params_hash)
    assert_equal 0, CentralPublishWorker::ActiveTicketWorker.jobs.size
  ensure
    Account.current.launch(:ticket_central_publish)
  end

  def test_central_publish_with_launch_party_enabled
    CentralPublishWorker::ActiveTicketWorker.jobs.clear
    t = create_ticket(ticket_params_hash)
    assert_equal 1, CentralPublishWorker::ActiveTicketWorker.jobs.size
  end

  def test_central_publish_payload
    custom_fields_hash = { "test_custom_dropdown_#{@account.id}" => DROPDOWN_CHOICES.sample, "test_custom_text_#{@account.id}" => 'Sample Text' }
    t = create_ticket(ticket_params_hash.merge(custom_field: custom_fields_hash))
    payload = t.central_publish_payload.to_json
    payload.must_match_json_expression(cp_ticket_pattern(t))
    assoc_payload = t.associations_to_publish.to_json
    assoc_payload.must_match_json_expression(cp_assoc_ticket_pattern(t))
  end

  def test_central_publish_payload_event_info
    custom_fields_hash = { "test_custom_dropdown_#{@account.id}" => DROPDOWN_CHOICES.sample, "test_custom_text_#{@account.id}" => 'Sample Text' }
    t = create_ticket(ticket_params_hash.merge(custom_field: custom_fields_hash))
    payload = t.central_publish_payload.to_json
    payload.must_match_json_expression(cp_ticket_pattern(t))
    event_info = t.event_info(:create)
    event_info.must_match_json_expression(cp_ticket_event_info_pattern(t))
  end

  def test_central_publish_payload_event_info_on_split_ticket
    custom_fields_hash = { "test_custom_dropdown_#{@account.id}" => DROPDOWN_CHOICES.sample, "test_custom_text_#{@account.id}" => 'Sample Text' }
    t = create_ticket(ticket_params_hash.merge(custom_field: custom_fields_hash))
    t.activity_type = { type: Helpdesk::Ticket::SPLIT_TICKET_ACTIVITY, soure_ticket_id: [1], source_note_id: [2] }
    payload = t.central_publish_payload.to_json
    payload.must_match_json_expression(cp_ticket_pattern(t))
    event_info = t.event_info(:create)
    event_info.must_match_json_expression(cp_ticket_event_info_pattern(t))
  end

  def test_central_publish_payload_event_info_on_merge_ticket
    custom_fields_hash = { "test_custom_dropdown_#{@account.id}" => DROPDOWN_CHOICES.sample, "test_custom_text_#{@account.id}" => 'Sample Text' }
    t = create_ticket(ticket_params_hash.merge(custom_field: custom_fields_hash))
    t.activity_type = { type: Helpdesk::Ticket::MERGE_TICKET_ACTIVITY, soure_ticket_id: [1], target_ticket_id: [2] }
    payload = t.central_publish_payload.to_json
    payload.must_match_json_expression(cp_ticket_pattern(t))
    event_info = t.event_info(:update)
    event_info.must_match_json_expression(cp_ticket_event_info_pattern(t))
  end

  def test_central_publish_payload_event_info_on_ticket_from_social_tab
    custom_fields_hash = { "test_custom_dropdown_#{@account.id}" => DROPDOWN_CHOICES.sample, "test_custom_text_#{@account.id}" => 'Sample Text' }
    t = create_ticket(ticket_params_hash.merge(custom_field: custom_fields_hash))
    t.activity_type = { type: Social::Constants::TWITTER_FEED_TICKET }
    payload = t.central_publish_payload.to_json
    payload.must_match_json_expression(cp_ticket_pattern(t))
    event_info = t.event_info(:create)
    event_info.must_match_json_expression(cp_ticket_event_info_pattern(t))
  end

  def test_central_publish_payload_without_custom_fields
    @account.ticket_fields.custom_fields.each(&:destroy)
    @account.reload
    t = create_ticket(ticket_params_hash)
    payload = t.central_publish_payload.to_json
    payload.must_match_json_expression(cp_ticket_pattern(t))
  end

  def test_central_publish_payload_with_responder_and_group
    group = create_group_with_agents(@account, agent_list: [@agent.id])
    t = create_ticket(ticket_params_hash(responder_id: @agent.id, group_id: group.id))
    payload = t.central_publish_payload.to_json
    payload.must_match_json_expression(cp_ticket_pattern(t))
    assoc_payload = t.associations_to_publish.to_json
    assoc_payload.must_match_json_expression(cp_assoc_ticket_pattern(t))
  end

  def test_central_publish_payload_with_first_response
    group = create_group_with_agents(@account, agent_list: [@agent.id])
    t = create_ticket(ticket_params_hash(responder_id: @agent.id, group_id: group.id))
    n = create_note(create_note(source: 0, ticket_id: t.id, user_id: @agent.id, private: false, body: Faker::Lorem.paragraph))
    payload = t.central_publish_payload.to_json
    payload.must_match_json_expression(cp_ticket_pattern(t))
    assoc_payload = t.associations_to_publish.to_json
    assoc_payload.must_match_json_expression(cp_assoc_ticket_pattern(t))
  end

  def test_central_publish_payload_agent_update
    group = create_group_with_agents(@account, agent_list: [@agent.id])
    t = create_ticket(ticket_params_hash(group_id: group.id))
    t.reload
    t.update_attributes(responder_id: @agent.id)
    payload = t.central_publish_payload.to_json
    payload.must_match_json_expression(cp_ticket_pattern(t))
    assoc_payload = t.associations_to_publish.to_json
    assoc_payload.must_match_json_expression(cp_assoc_ticket_pattern(t))
  end

  def test_central_publish_payload_group_update
    group = create_group_with_agents(@account, agent_list: [@agent.id])
    t = create_ticket(ticket_params_hash(responder_id: @agent.id))
    t.reload
    t.update_attributes(group_id: group.id)
    payload = t.central_publish_payload.to_json
    payload.must_match_json_expression(cp_ticket_pattern(t))
    assoc_payload = t.associations_to_publish.to_json
    assoc_payload.must_match_json_expression(cp_assoc_ticket_pattern(t))
  end

  def test_central_publish_payload_with_tags
    t = create_ticket(ticket_params_hash(tags: [Faker::Lorem.word, Faker::Lorem.word].join(',')))
    payload = t.central_publish_payload.to_json
    payload.must_match_json_expression(cp_ticket_pattern(t))
  end

  def test_central_publish_update_action
    t = create_ticket(ticket_params_hash)
    CentralPublishWorker::ActiveTicketWorker.jobs.clear
    t.reload
    t.update_attributes(priority: 4)
    payload = t.central_publish_payload.to_json
    payload.must_match_json_expression(cp_ticket_pattern(t))
    assert_equal 1, CentralPublishWorker::ActiveTicketWorker.jobs.size
    job = CentralPublishWorker::ActiveTicketWorker.jobs.last
    assert_equal 'ticket_update', job['args'][0]
    assert_equal({ 'priority' => [2, 4] }, job['args'][1]['model_changes'])
  end

  def test_central_publish_tag_update
    t = create_ticket(ticket_params_hash)
    CentralPublishWorker::ActiveTicketWorker.jobs.clear
    t.reload
    tag = Faker::Lorem.word
    t.tags.build(name: tag)
    t.save_ticket
    t.reload
    payload = t.central_publish_payload.to_json
    payload.must_match_json_expression(cp_ticket_pattern(t))
    assert_equal 1, CentralPublishWorker::ActiveTicketWorker.jobs.size
    job = CentralPublishWorker::ActiveTicketWorker.jobs.last
    assert_equal 'ticket_update', job['args'][0]
    assert_equal({ 'tags' => { 'added' => [tag], 'removed' => [] } }, job['args'][1]['model_changes'])
  end

  def test_central_publish_watcher_event
    t = create_ticket(ticket_params_hash)
    CentralPublishWorker::ActiveTicketWorker.jobs.clear
    User.stubs(:current).returns(@agent)
    subscription = t.subscriptions.build(:user_id => @agent.id)
    subscription.save
    t.reload
    payload = t.central_publish_payload.to_json
    payload.must_match_json_expression(cp_ticket_pattern(t))
    assert_equal 1, CentralPublishWorker::ActiveTicketWorker.jobs.size
    job = CentralPublishWorker::ActiveTicketWorker.jobs.last
    assert_equal 'ticket_update', job['args'][0]
    assert_equal({ 'watchers' => { 'added' => [@agent.id], 'removed' => [] } }, job['args'][1]['model_changes'])
  ensure
    User.unstub(:current)
  end

  def test_prevent_central_publish_watcher_if_actor_is_system
    t = create_ticket(ticket_params_hash)
    CentralPublishWorker::ActiveTicketWorker.jobs.clear
    User.stubs(:current).returns(nil)
    subscription = t.subscriptions.build(:user_id => @agent.id)
    subscription.save
    assert_equal 0, CentralPublishWorker::ActiveTicketWorker.jobs.size
  ensure
    User.unstub(:current)
  end

  def test_central_publish_description_update
    t = create_ticket(ticket_params_hash)
    CentralPublishWorker::ActiveTicketWorker.jobs.clear
    t.reload
    t.description = Faker::Lorem.characters(500)
    t.save_ticket
    payload = t.central_publish_payload.to_json
    payload.must_match_json_expression(cp_ticket_pattern(t))
    assert_equal 1, CentralPublishWorker::ActiveTicketWorker.jobs.size
    job = CentralPublishWorker::ActiveTicketWorker.jobs.last
    assert_equal 'ticket_update', job['args'][0]
    assert_equal({ 'description' => [nil, '*'] }, job['args'][1]['model_changes'])
  end

  def test_central_publish_custom_fields_update
    custom_fields_hash = { "test_custom_dropdown_#{@account.id}" => DROPDOWN_CHOICES.first }
    t = create_ticket(ticket_params_hash.merge(custom_field: custom_fields_hash))
    CentralPublishWorker::ActiveTicketWorker.jobs.clear
    t.reload
    t.update_attributes("test_custom_dropdown_#{@account.id}" => DROPDOWN_CHOICES.last)
    payload = t.central_publish_payload.to_json
    payload.must_match_json_expression(cp_ticket_pattern(t))
    assert_equal 1, CentralPublishWorker::ActiveTicketWorker.jobs.size
    job = CentralPublishWorker::ActiveTicketWorker.jobs.last
    assert_equal 'ticket_update', job['args'][0]
    assert_equal({ "test_custom_dropdown_#{@account.id}" => [DROPDOWN_CHOICES.first, DROPDOWN_CHOICES.last] }, job['args'][1]['model_changes'])
  end

  def test_central_publish_ticket_destroy
    t = create_ticket(ticket_params_hash)
    pattern_to_match = cp_ticket_destroy_pattern(t)
    CentralPublishWorker::ActiveTicketWorker.jobs.clear
    t = @account.tickets.find(t.id)
    t.destroy
    assert_equal 1, CentralPublishWorker::ActiveTicketWorker.jobs.size
    job = CentralPublishWorker::ActiveTicketWorker.jobs.last
    assert_equal 'ticket_destroy', job['args'][0]
    assert_equal({}, job['args'][1]['model_changes'])
    job['args'][1]['model_properties'].must_match_json_expression(pattern_to_match)
  end

  def test_central_publish_ticket_destroy_while_archive_action
    archive_enabled = @account.archive_tickets_enabled?
    archive_action = true
    @account.features.archive_tickets.create unless archive_enabled
    t = create_ticket(ticket_params_hash)
    pattern_to_match = cp_ticket_destroy_pattern_for_archive_action(t)
    CentralPublishWorker::ActiveTicketWorker.jobs.clear
    t = @account.tickets.find(t.id)
    t.destroy
    assert_equal t.save_deleted_ticket_info(archive_action), pattern_to_match
    @account.features.archive_tickets.delete unless archive_enabled
  end

  def test_block_central_publish_for_suspended_accounts
    skip('skip failing test cases')
    @account.subscription.state = 'suspended'
    @account.subscription.save
    CentralPublishWorker::ActiveTicketWorker.jobs.clear
    t = create_ticket(ticket_params_hash)
    assert_equal 0, CentralPublishWorker::ActiveTicketWorker.jobs.size
  ensure
    @account.subscription.state = 'active'
    @account.subscription.save
  end

  def test_central_publish_payload_with_source_additional_info_twitter
    t = create_twitter_ticket
    payload = t.central_publish_payload.to_json
    payload.must_match_json_expression(cp_ticket_pattern(t))
  end

  def test_central_publish_payload_with_source_additional_info_facebook
    t = create_fb_ticket
    payload = t.central_publish_payload.to_json
    payload.must_match_json_expression(cp_ticket_pattern(t))
  end

  def test_source_additional_info_fb_with_page_destroy_ticket_update
    ticket = create_fb_ticket
    Social::FbPost.any_instance.stubs(:facebook_page).returns(nil)
    ticket.update_attributes(status: 5)
    payload = ticket.central_publish_payload.to_json
    payload.must_match_json_expression(cp_ticket_pattern(ticket))
  ensure
    Social::FbPost.any_instance.unstub(:facebook_page)
  end

  def test_source_additional_info_twitter_with_handle_destroy_ticket_update
    Account.any_instance.stubs(:twitter_handle_publisher_enabled?).returns(false)
    handle = create_twitter_handle
    t = create_twitter_ticket(twitter_handle: handle)
    handle.delete
    t.update_attributes(status: 5)
    payload = t.central_publish_payload.to_json
    payload.must_match_json_expression(cp_ticket_pattern(t))
  ensure
    Account.any_instance.unstub(:twitter_handle_publisher_enabled?)
  end

  def test_source_additional_info_email_received_at
    t = create_ticket(ticket_params_hash.merge(source: 1))
    t.update_attributes(status: 5)
    t.schema_less_ticket.header_info[:received_at] = Time.now.utc.iso8601
    payload = t.central_publish_payload.to_json
    payload.must_match_json_expression(cp_ticket_pattern(t))
  end

  def test_source_additional_info_email_received_at_no_value
    t = create_ticket(ticket_params_hash.merge(source: 1))
    t.update_attributes(status: 5)
    t.schema_less_ticket.header_info[:received_at] = nil
    payload = t.central_publish_payload.to_json
    payload.must_match_json_expression(cp_ticket_pattern(t))
  end

  def test_central_publish_payload_public_note
    group = create_group_with_agents(@account, agent_list: [@agent.id])
    ticket = create_ticket(ticket_params_hash(responder_id: @agent.id, group_id: group.id))
    CentralPublishWorker::ActiveTicketWorker.jobs.clear
    create_note(source: 0, ticket_id: ticket.id, user_id: @agent.id, private: false, body: Faker::Lorem.paragraph)
    assert_equal 2, CentralPublishWorker::ActiveTicketWorker.jobs.size
    job = CentralPublishWorker::ActiveTicketWorker.jobs.first
    assert_equal 'ticket_update', job['args'][0]
    assert_equal({ 'agent_reply_count' => [nil, 1] }, job['args'][1]['model_changes'])
  end

  def test_ticket_state_worker_central_publish
    group = create_group_with_agents(@account, agent_list: [@agent.id])
    ticket = create_ticket(ticket_params_hash(responder_id: @agent.id, group_id: group.id))
    note = create_note(source: 0, ticket_id: ticket.id, user_id: @agent.id, private: false, body: Faker::Lorem.paragraph)
    input = {
      id: note.id,
      model_changes: nil,
      freshdesk_webhook: false,
      current_user_id: @agent.id
    }
    CentralPublishWorker::ActiveTicketWorker.jobs.clear
    Tickets::UpdateTicketStatesWorker.new.perform(input)
    assert_equal 2, CentralPublishWorker::ActiveTicketWorker.jobs.size
    schema_less_ticket_job = CentralPublishWorker::ActiveTicketWorker.jobs.first
    ticket_state_job = CentralPublishWorker::ActiveTicketWorker.jobs.last
    ticket_state = ticket.ticket_states.reload
    schema_less_ticket = ticket.schema_less_ticket.reload
    assert_equal 'ticket_update', ticket_state_job['args'][0]
    assert_equal 'ticket_update', schema_less_ticket_job['args'][0]
    assert_equal({ 'first_response_time' => [nil, ticket_state.first_response_time],
                   'first_response_by_bhrs' => [nil, ticket_state.first_resp_time_by_bhrs] }, ticket_state_job['args'][1]['model_changes'])
    assert_equal({ 'first_response_id' => [nil, schema_less_ticket.reports_hash['first_response_id']],
                   'first_response_agent_id' => [nil, schema_less_ticket.reports_hash['first_response_agent_id']] }, schema_less_ticket_job['args'][1]['model_changes'])
  end
end
