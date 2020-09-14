# frozen_string_literal: true

require_relative '../../test_helper'
['tickets_test_helper.rb', 'archive_ticket_test_helper.rb', 'attachments_test_helper.rb', 'ticket_fields_test_helper.rb'].each { |file| require Rails.root.join('test', 'api', 'helpers', file) }
['account_helper.rb', 'user_helper.rb'].each { |file| require Rails.root.join('spec', 'support', file) }
['skills_test_helper.rb'].each { |file| require Rails.root.join('test', 'api', 'helpers', 'admin', file) }
['social_tickets_creation_helper'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
['users_test_helper.rb'].each { |file| require "#{Rails.root}/test/core/helpers/#{file}" }

class ArchiveTicketsTest < ActiveSupport::TestCase
  include ArchiveTicketsTestHelper # helper for central payload
  include ArchiveTicketTestHelper
  include AttachmentsTestHelper
  include ApiTicketsTestHelper
  include AccountHelper
  include UsersHelper
  include TicketFieldsTestHelper
  include Admin::SkillsTestHelper
  include SocialTicketsCreationHelper
  include CoreUsersTestHelper

  ARCHIVE_DAYS = 120
  DROPDOWN_CHOICES = ['Get Smart', 'Pursuit of Happiness', 'Armaggedon'].freeze

  def setup
    super
    @account = Account.current
    before_all
  end

  @@before_all_run = false

  def before_all
    @ticket_update_date = 150.days.ago
    @account.add_features(:archive_tickets)
    @account.enable_ticket_archiving(ARCHIVE_DAYS)
    return if @@before_all_run

    @account.remove_feature(:skill_based_round_robin)
    @account.subscription.state = 'active'
    @account.subscription.save
    @account.launch(:archive_ticket_central_publish)
    @@before_all_run = true
  end

  def test_central_publish_payload
    create_archive_ticket_with_assoc(
      created_at: @ticket_update_date,
      updated_at: @ticket_update_date,
      create_association: true,
      header_info: { received_at: Time.now.utc.iso8601 }
    )
    stub_archive_assoc_for_show(@archive_association) do
      archive_ticket = @account.archive_tickets.where(ticket_id: @archive_ticket.id).first
      payload = archive_ticket.central_publish_payload.to_json
      payload.must_match_json_expression(central_payload_archive_ticket_pattern(archive_ticket))
      assoc_payload = archive_ticket.associations_to_publish.to_json
      assoc_payload.must_match_json_expression(central_publish_assoc_archive_ticket_pattern(archive_ticket))
      archive_ticket.destroy
    end
  end

  def test_central_publish_payload_with_custom_text_field_and_custom_file
    flexifield_def = FlexifieldDef.where(account_id: @account.id, 'module': 'Ticket').first
    attachment = create_file_ticket_field_attachment
    custom_text_field = create_custom_field(Faker::Lorem.word, 'text')
    file_field_col_name = flexifield_def.first_available_column('file')
    custom_file_field = create_custom_field_dn('test_file_field', 'file', false, false, flexifield_name: file_field_col_name)
    create_archive_ticket_with_assoc(
      created_at: @ticket_update_date,
      updated_at: @ticket_update_date,
      create_association: true,
      custom_file_field_value: attachment.id,
      header_info: { received_at: Time.now.utc.iso8601 }
    )
    stub_archive_assoc_for_show(@archive_association) do
      @archive_association.association_data['helpdesk_tickets_association']['flexifield'].stringify_keys!
      archive_ticket = @account.archive_tickets.where(ticket_id: @archive_ticket.id).first
      payload = archive_ticket.central_publish_payload.to_json
      payload.must_match_json_expression(central_payload_archive_ticket_pattern(archive_ticket))
      assoc_payload = archive_ticket.associations_to_publish.to_json
      assoc_payload.must_match_json_expression(central_publish_assoc_archive_ticket_pattern(archive_ticket))
      archive_ticket.destroy
    end
  ensure
    attachment.destroy
    custom_file_field.destroy
    custom_text_field.destroy
  end

  def test_central_publish_payload_with_custom_dropdown_field_and_date_field
    custom_drop_down = create_custom_field_dropdown('test_custom_dropdown', DROPDOWN_CHOICES)
    custom_dropdown_value = DROPDOWN_CHOICES.sample
    custom_date_field = create_custom_field('EOD', 'date')
    create_archive_ticket_with_assoc(
      created_at: @ticket_update_date,
      updated_at: @ticket_update_date,
      create_association: true,
      custom_field_value: custom_dropdown_value,
      header_info: { received_at: Time.now.utc.iso8601 }
    )
    stub_archive_assoc_for_show(@archive_association) do
      @archive_association.association_data['helpdesk_tickets_association']['flexifield'].stringify_keys!
      archive_ticket = @account.archive_tickets.where(ticket_id: @archive_ticket.id).first
      payload = archive_ticket.central_publish_payload.to_json
      payload.must_match_json_expression(central_payload_archive_ticket_pattern(archive_ticket))
      assoc_payload = archive_ticket.associations_to_publish.to_json
      assoc_payload.must_match_json_expression(central_publish_assoc_archive_ticket_pattern(archive_ticket))
      archive_ticket.destroy
    end
  ensure
    custom_drop_down.destroy
    custom_date_field.destroy
  end

  def test_central_publish_payload_with_enabled_skill_and_next_reponse_sla
    @account.stubs(:skill_based_round_robin_enabled?).returns(true)
    @account.stubs(:next_response_sla_enabled?).returns(true)
    skill_column = create_dummy_skill
    create_archive_ticket_with_assoc(
      created_at: @ticket_update_date,
      updated_at: @ticket_update_date,
      create_association: true,
      nr_due_by: Time.zone.now.utc,
      nr_escalated: true,
      nr_reminded: true,
      sl_skill_id: skill_column[:id],
      header_info: { received_at: Time.now.utc.iso8601 }
    )
    stub_archive_assoc_for_show(@archive_association) do
      archive_ticket = @account.archive_tickets.where(ticket_id: @archive_ticket.id).first
      payload = archive_ticket.central_publish_payload.to_json
      payload.must_match_json_expression(central_payload_archive_ticket_pattern(archive_ticket))
      assoc_payload = archive_ticket.associations_to_publish.to_json
      assoc_payload.must_match_json_expression(central_publish_assoc_archive_ticket_pattern(archive_ticket))
      assert_equal true, archive_ticket.nr_escalated
      assert_equal true, archive_ticket.nr_reminded
      assert_equal skill_column[:id], archive_ticket.sl_skill_id
      archive_ticket.destroy
    end
  ensure
    @account.unstub(:skill_based_round_robin_enabled?)
    @account.unstub(:next_response_sla_enabled?)
    skill_column.destroy
  end

  def test_central_publish_payload_with_reports_hash_value
    reports_hash = { 'first_assign_by_bhrs' => 0.0, 'first_assign_agent_id' => 1, 'agent_assigned_flag' => true }
    ticket_states = { first_assigned_at: Time.zone.now.utc }
    create_archive_ticket_with_assoc(
      created_at: @ticket_update_date,
      updated_at: @ticket_update_date,
      create_association: true,
      reports_hash: reports_hash,
      ticket_states: ticket_states,
      header_info: { received_at: Time.now.utc.iso8601 }
    )
    stub_archive_assoc_for_show(@archive_association) do
      archive_ticket = @account.archive_tickets.where(ticket_id: @archive_ticket.id).first
      payload = archive_ticket.central_publish_payload.to_json
      payload.must_match_json_expression(central_payload_archive_ticket_pattern(archive_ticket))
      assoc_payload = archive_ticket.associations_to_publish.to_json
      assoc_payload.must_match_json_expression(central_publish_assoc_archive_ticket_pattern(archive_ticket))
      assert_equal reports_hash, archive_ticket.reports_hash
      archive_ticket.destroy
    end
  end

  def test_central_publish_payload_with_association_type
    create_archive_ticket_with_assoc(
      created_at: @ticket_update_date,
      updated_at: @ticket_update_date,
      create_association: true,
      association_type: 4,
      header_info: { received_at: Time.now.utc.iso8601 }
    )
    stub_archive_assoc_for_show(@archive_association) do
      archive_ticket = @account.archive_tickets.where(ticket_id: @archive_ticket.id).first
      payload = archive_ticket.central_publish_payload.to_json
      payload.must_match_json_expression(central_payload_archive_ticket_pattern(archive_ticket))
      assoc_payload = archive_ticket.associations_to_publish.to_json
      assoc_payload.must_match_json_expression(central_publish_assoc_archive_ticket_pattern(archive_ticket))
      archive_ticket.destroy
    end
  end

  def test_central_publish_payload_with_group_users
    create_archive_ticket_with_assoc(
      created_at: @ticket_update_date,
      updated_at: @ticket_update_date,
      create_association: true,
      header_info: { received_at: Time.now.utc.iso8601 }
    )
    stub_archive_assoc_for_show(@archive_association) do
      archive_ticket = @account.archive_tickets.where(ticket_id: @archive_ticket.id).first
      archive_ticket.attributes = { group_id: @create_group.id, group: @create_group }
      archive_ticket.save
      payload = archive_ticket.central_publish_payload.to_json
      payload.must_match_json_expression(central_payload_archive_ticket_pattern(archive_ticket))
      assoc_payload = archive_ticket.associations_to_publish.to_json
      assoc_payload.must_match_json_expression(central_publish_assoc_archive_ticket_pattern(archive_ticket))
      archive_ticket.destroy
    end
  end

  def test_central_publish_payload_with_source_additional_info_twitter
    create_archive_ticket_with_assoc(
      created_at: @ticket_update_date,
      updated_at: @ticket_update_date,
      create_association: true,
      create_twitter_ticket: true,
      tweet_type: 'mention',
      header_info: { received_at: Time.now.utc.iso8601 }
    )
    stub_archive_assoc_for_show(@archive_association) do
      archive_ticket = @account.archive_tickets.where(ticket_id: @archive_ticket.id).first
      payload = archive_ticket.central_publish_payload.to_json
      payload.must_match_json_expression(central_payload_archive_ticket_pattern(archive_ticket))
      assoc_payload = archive_ticket.associations_to_publish.to_json
      assoc_payload.must_match_json_expression(central_publish_assoc_archive_ticket_pattern(archive_ticket))
      archive_ticket.destroy
    end
  end

  def test_central_publish_payload_with_parent_ticket
    ticket = create_ticket
    create_archive_ticket_with_assoc(
      created_at: @ticket_update_date,
      updated_at: @ticket_update_date,
      create_association: true,
      parent_ticket_id: ticket.id,
      header_info: { received_at: Time.now.utc.iso8601 }
    )
    stub_archive_assoc_for_show(@archive_association) do
      archive_ticket = @account.archive_tickets.where(ticket_id: @archive_ticket.id).first
      payload = archive_ticket.central_publish_payload.to_json
      payload.must_match_json_expression(central_payload_archive_ticket_pattern(archive_ticket))
      assoc_payload = archive_ticket.associations_to_publish.to_json
      assoc_payload.must_match_json_expression(central_publish_assoc_archive_ticket_pattern(archive_ticket))
      archive_ticket.destroy
    end
  ensure
    ticket.destroy
  end

  def test_for_archive_ticket_disallow_payload
    create_archive_ticket_with_assoc(
      created_at: @ticket_update_date,
      updated_at: @ticket_update_date,
      create_association: true,
      header_info: { received_at: Time.now.utc.iso8601 }
    )
    stub_archive_assoc_for_show(@archive_association) do
      new_user = add_new_user(@account)
      archive_ticket = @account.archive_tickets.where(ticket_id: @archive_ticket.id).first
      central_publish_options = { model_changes: { requester_id: [archive_ticket.requester_id, new_user.id] } }
      archive_ticket.attributes = { requester_id: new_user.id }
      archive_ticket.save
      payload = archive_ticket.manual_publish(nil, [:update, central_publish_options], false)
      assert_nil payload
      archive_ticket.destroy
      new_user.destroy
    end
  end
end
