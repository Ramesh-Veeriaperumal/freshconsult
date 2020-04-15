require_relative '../../test_helper'
require_relative '../../../test_helper'
['ticket_fields_test_helper.rb', 'tickets_test_helper.rb'].each { |file| require "#{Rails.root}/test/api/helpers/#{file}" }
['note_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
['social_tickets_creation_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
['shared_ownership_test_helper.rb'].each { |file| require "#{Rails.root}/test/core/helpers/#{file}" }

class TicketTest < ActiveSupport::TestCase
  include TicketsTestHelper
  include ApiTicketsTestHelper
  include TicketFieldsTestHelper
  include ModelsGroupsTestHelper
  include NoteHelper
  include SocialTicketsCreationHelper
  include ProductTestHelper
  include SharedOwnershipTestHelper
  include PrivilegesHelper
  include UsersTestHelper

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

  def test_central_publish_payload_event_info_with_hypertrail_enabled
    custom_fields_hash = { "test_custom_dropdown_#{@account.id}" => DROPDOWN_CHOICES.sample, "test_custom_text_#{@account.id}" => 'Sample Text' }
    Account.any_instance.stubs(:hypertrail_activities_enabled?).returns(true)
    t = create_ticket(ticket_params_hash.merge(custom_field: custom_fields_hash))
    payload = t.central_publish_payload.to_json
    payload.must_match_json_expression(cp_ticket_pattern(t))
    event_info = t.event_info(:create)
    assert_equal event_info[:hypertrail], true
    event_info.must_match_json_expression(cp_ticket_event_info_pattern(t))
    Account.any_instance.stubs(:hypertrail_activities_enabled?).returns(false)
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
    assert_equal({ 'priority' => [2, 4] }, job['args'][1]['model_changes'].except('due_by', 'frDueBy'))
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
    handle = create_twitter_handle
    t = create_twitter_ticket(twitter_handle: handle)
    handle.delete
    t.update_attributes(status: 5)
    payload = t.central_publish_payload.to_json
    payload.must_match_json_expression(cp_ticket_pattern(t))
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

  def test_central_publish_payload_product_update_with_value
    product = create_product(@account)
    t = create_ticket
    t.reload
    t.update_attributes(product_id: product.id)
    payload = t.central_publish_payload.to_json
    payload.must_match_json_expression(cp_ticket_pattern(t))
    assoc_payload = t.associations_to_publish.to_json
    assoc_payload.must_match_json_expression(cp_assoc_ticket_pattern(t))
  end

  def test_central_publish_payload_with_skill
    Account.any_instance.stubs(:skill_based_round_robin_enabled?).returns(true)
    create_skill_tickets
    t = @account.tickets.last
    payload = t.central_publish_payload.to_json
    payload.must_match_json_expression(cp_ticket_pattern(t))
    assoc_payload = t.associations_to_publish
    assert_equal assoc_payload[:skill], skill_key_value_pairs(t)
    assoc_payload.to_json.must_match_json_expression(cp_assoc_ticket_pattern(t))
    Account.any_instance.unstub(:skill_based_round_robin_enabled?)
  end

  def test_central_publish_payload_event_info_on_round_robin
    t = create_ticket(ticket_params_hash.merge(responder_id: @agent.id))
    t.activity_type = { type: 'round_robin', responder_id: [nil, t.responder_id] }
    payload = t.central_publish_payload.to_json
    payload.must_match_json_expression(cp_ticket_pattern(t))
    event_info = t.event_info(:create)
    event_info.must_match_json_expression(cp_ticket_event_info_pattern(t))
  end
 
  def test_central_publish_internal_agent_associations
    Account.any_instance.stubs(:shared_ownership_enabled?).returns(true)
    initialize_internal_agent_with_default_internal_group(permission = 3)
    ticket = create_ticket({ status: @status.status_id, responder_id: nil, internal_agent_id: @internal_agent.id }, nil, @internal_group)
    payload = ticket.central_publish_payload.to_json
    payload.must_match_json_expression(cp_ticket_pattern(ticket))
    assoc_payload = ticket.associations_to_publish.to_json
    assoc_payload.must_match_json_expression(cp_assoc_ticket_pattern(ticket))
    internal_agent_pattern = ticket.internal_agent.as_api_response(:internal_agent_central_publish_associations).to_json
    internal_agent_pattern.must_match_json_expression(internal_agent_association_pattern(ticket))
    Account.any_instance.unstub(:shared_ownership_enabled?)
  end

  def test_central_publish_internal_group_associations
    Account.any_instance.stubs(:shared_ownership_enabled?).returns(true)
    initialize_internal_agent_with_default_internal_group(permission = 3)
    ticket = create_ticket({ status: @status.status_id, responder_id: nil, internal_agent_id: @internal_agent.id }, nil, @internal_group)
    payload = ticket.central_publish_payload.to_json
    payload.must_match_json_expression(cp_ticket_pattern(ticket))
    assoc_payload = ticket.associations_to_publish.to_json
    assoc_payload.must_match_json_expression(cp_assoc_ticket_pattern(ticket))
    internal_group_pattern = ticket.internal_group.as_api_response(:internal_group_central_publish_associations).to_json
    internal_group_pattern.must_match_json_expression(internal_group_association_pattern(ticket))
    Account.any_instance.unstub(:shared_ownership_enabled?)
  end

  def test_central_publish_fr_reminded
    t = create_ticket(ticket_params_hash.merge(responder_id: @agent.id))
    t.sla_policy.update_attributes(escalations: {reminder_response: {"1": {time: -1800, agents_id: [-1]}}}.with_indifferent_access)
    t.reload
    t.sla_response_reminded = true
    CentralPublishWorker::ActiveTicketWorker.jobs.clear
    t.save
    payload = t.central_publish_payload.to_json
    payload.must_match_json_expression(cp_ticket_pattern(t))
    assert_equal 1, CentralPublishWorker::ActiveTicketWorker.jobs.size
    job = CentralPublishWorker::ActiveTicketWorker.jobs.last
    assert_equal 'ticket_update', job['args'][0]
    assert_equal([false, true], job['args'][1]['model_changes']['response_reminded'])
    assert_equal({'reminder_response' => [@agent.id]}, job['args'][1]['misc_changes']['notify_agents'])
  end

  def test_central_publish_resolution_reminded
    t = create_ticket(ticket_params_hash.merge(responder_id: @agent.id))
    t.sla_policy.update_attributes(escalations: {reminder_resolution: {"1": {time: -1800, agents_id: [-1]}}}.with_indifferent_access)
    t.reload
    t.sla_resolution_reminded = true
    CentralPublishWorker::ActiveTicketWorker.jobs.clear
    t.save
    payload = t.central_publish_payload.to_json
    payload.must_match_json_expression(cp_ticket_pattern(t))
    assert_equal 1, CentralPublishWorker::ActiveTicketWorker.jobs.size
    job = CentralPublishWorker::ActiveTicketWorker.jobs.last
    assert_equal 'ticket_update', job['args'][0]
    assert_equal([false, true], job['args'][1]['model_changes']['resolution_reminded'])
    assert_equal({'reminder_resolution' => [@agent.id]}, job['args'][1]['misc_changes']['notify_agents'])
  end

  def test_central_publish_nr_reminded
    Account.any_instance.stubs(:next_response_sla_enabled?).returns(true)
    t = create_ticket(ticket_params_hash.merge(responder_id: @agent.id))
    t.sla_policy.update_attributes(escalations: {reminder_next_response: {"1": {time: -1800, agents_id: [-1]}}}.with_indifferent_access)
    t.reload
    t.nr_reminded = true
    CentralPublishWorker::ActiveTicketWorker.jobs.clear
    t.save
    payload = t.central_publish_payload.to_json
    payload.must_match_json_expression(cp_ticket_pattern(t))
    assert_equal 1, CentralPublishWorker::ActiveTicketWorker.jobs.size
    job = CentralPublishWorker::ActiveTicketWorker.jobs.last
    assert_equal 'ticket_update', job['args'][0]
    assert_equal([false, true], job['args'][1]['model_changes']['next_response_reminded'])
    assert_equal({'reminder_next_response' => [@agent.id]}, job['args'][1]['misc_changes']['notify_agents'])
  ensure
    Account.any_instance.unstub(:next_response_sla_enabled?)
  end

  def test_central_publish_fr_escalated
    t = create_ticket(ticket_params_hash.merge(responder_id: @agent.id))
    t.sla_policy.update_attributes(escalations: {response: {"1": {time: 0, agents_id: [-1]}}}.with_indifferent_access)
    t.reload
    t.fr_escalated = true
    CentralPublishWorker::ActiveTicketWorker.jobs.clear
    t.save
    payload = t.central_publish_payload.to_json
    payload.must_match_json_expression(cp_ticket_pattern(t))
    assert_equal 1, CentralPublishWorker::ActiveTicketWorker.jobs.size
    job = CentralPublishWorker::ActiveTicketWorker.jobs.last
    assert_equal 'ticket_update', job['args'][0]
    assert_equal([false, true], job['args'][1]['model_changes']['fr_escalated'])
    assert_equal({'response' => [@agent.id]}, job['args'][1]['misc_changes']['notify_agents'])
  end

  def test_central_publish_resolution_escalated
    t = create_ticket(ticket_params_hash.merge(responder_id: @agent.id))
    t.sla_policy.update_attributes(escalations: {resolution: {"1": {time: 0, agents_id: [-1]}}}.with_indifferent_access)
    t.reload
    t.escalation_level = 1
    CentralPublishWorker::ActiveTicketWorker.jobs.clear
    t.save
    payload = t.central_publish_payload.to_json
    payload.must_match_json_expression(cp_ticket_pattern(t))
    assert_equal 1, CentralPublishWorker::ActiveTicketWorker.jobs.size
    job = CentralPublishWorker::ActiveTicketWorker.jobs.last
    assert_equal 'ticket_update', job['args'][0]
    assert_equal([nil, 1], job['args'][1]['model_changes']['resolution_escalation_level'])
    assert_equal({'resolution' => [@agent.id]}, job['args'][1]['misc_changes']['notify_agents'])
    t.reload
    t.escalation_level = 4
    CentralPublishWorker::ActiveTicketWorker.jobs.clear
    t.save
    payload = t.central_publish_payload.to_json
    payload.must_match_json_expression(cp_ticket_pattern(t))
    assert_equal 1, CentralPublishWorker::ActiveTicketWorker.jobs.size
    job = CentralPublishWorker::ActiveTicketWorker.jobs.last
    assert_equal 'ticket_update', job['args'][0]
    assert_equal([1, 4], job['args'][1]['model_changes']['resolution_escalation_level'])
    assert_equal({'resolution' => []}, job['args'][1]['misc_changes']['notify_agents'])
  end

  def test_central_publish_nr_escalated
    Account.any_instance.stubs(:next_response_sla_enabled?).returns(true)
    t = create_ticket(ticket_params_hash.merge(responder_id: @agent.id))
    t.sla_policy.update_attributes(escalations: {next_response: {"1": {time: 0, agents_id: [-1]}}}.with_indifferent_access)
    t.reload
    t.nr_escalated = true
    CentralPublishWorker::ActiveTicketWorker.jobs.clear
    t.save
    payload = t.central_publish_payload.to_json
    payload.must_match_json_expression(cp_ticket_pattern(t))
    assert_equal 1, CentralPublishWorker::ActiveTicketWorker.jobs.size
    job = CentralPublishWorker::ActiveTicketWorker.jobs.last
    assert_equal 'ticket_update', job['args'][0]
    assert_equal([false, true], job['args'][1]['model_changes']['nr_escalated'])
    assert_equal({'next_response' => [@agent.id]}, job['args'][1]['misc_changes']['notify_agents'])
  ensure
    Account.any_instance.unstub(:next_response_sla_enabled?)
  end

  def test_central_publish_payload_with_secure_field
    @account = Account.first.nil? ? create_test_account : Account.first.make_current
    create_custom_field_dn('custom_card_no_test', 'secure_text')
    params = ticket_params_hash
    t = create_ticket(params)
    CentralPublishWorker::ActiveTicketWorker.jobs.clear
    t.update_attributes("custom_card_no_test_#{@account.id}": 'changed')
    t.save
    custom_fields_payload = t.central_publish_payload[:custom_fields]
    secure_field_payload = custom_fields_payload.select { |cf| cf[:label] == 'custom_card_no_test' }
    assert_equal secure_field_payload.first[:value], '*'
    payload = t.central_publish_payload.to_json
    payload.must_match_json_expression(cp_ticket_pattern(t))
  ensure
    t.destroy
    @account.ticket_fields.find_by_name("custom_card_no_test_#{@account.id}").destroy
  end
end
