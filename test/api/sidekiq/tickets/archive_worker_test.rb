require_relative '../../unit_test_helper'
require_relative '../../helpers/archive_ticket_test_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!
require Rails.root.join('spec', 'support', 'user_helper.rb')
require Rails.root.join('test', 'api', 'helpers', 'tickets_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'controller_test_helper.rb')

class Archive::TicketWorkerTest < ActionView::TestCase
  include ApiTicketsTestHelper
  include UsersHelper
  include ControllerTestHelper
  include ArchiveTicketTestHelper

  ARCHIVE_DAYS = 120
  TICKET_UPDATED_DATE = 150.days.ago

  def setup
    Account.stubs(:current).returns(Account.first)
    @account = Account.current
    current_shard = ShardMapping.find_by_account_id(@account.id).shard_name
    @disable_archive_enabled = Account.current.disable_archive_enabled?
    Account.current.disable_setting(:disable_archive) if @disable_archive_enabled
    ArchiveNoteConfig[current_shard] = 0
    @account.enable_ticket_archiving(ARCHIVE_DAYS)
  end

  def teardown
    Account.unstub(:current)
    Account.current.enable_setting(:disable_archive) if @disable_archive_enabled
  end

  def test_archive_ticket_without_ticket_state
    ticket = prepare_archive_ticket
    missing_field = Helpdesk::TicketState.find_by_ticket_id(ticket.id)
    missing_field.destroy
    ticket.reload
    disable_archive_on_missing_assoc
    assert_raise_with_message(MissionAssociationError, "ticket_states association is missing") {
      convert_ticket_to_archive(ticket)
    }
  ensure
    Account.current.launch(:archive_on_missing_associations) if @archive_missing_launched
  end

  def test_archive_ticket_without_schema_less
    ticket = prepare_archive_ticket
    missing_field = Helpdesk::SchemaLessTicket.find_by_ticket_id(ticket.id)
    missing_field.destroy
    ticket.reload
    disable_archive_on_missing_assoc
    assert_raise_with_message(MissionAssociationError, "schema_less_ticket association is missing") {
      convert_ticket_to_archive(ticket)
    }
  ensure
    Account.current.launch(:archive_on_missing_associations) if @archive_missing_launched
  end

  def test_archive_ticket_without_flexifield
    ticket = prepare_archive_ticket
    missing_field = Flexifield.find_by_flexifield_set_id(ticket.id)
    missing_field.destroy
    ticket.reload
    disable_archive_on_missing_assoc
    assert_raise_with_message(MissionAssociationError, "flexifield association is missing") {
      convert_ticket_to_archive(ticket)
    }
  ensure
    Account.current.launch(:archive_on_missing_associations) if @archive_missing_launched
  end

  def test_archive_ticket_missing_schema_less_assoc_with_feature
    ticket = prepare_archive_ticket
    missing_field = Helpdesk::SchemaLessTicket.find_by_ticket_id(ticket.id)
    missing_field.destroy
    ticket.reload
    enable_archive_on_missing_assoc
    convert_ticket_to_archive(ticket)
    archive_ticket = Helpdesk::ArchiveTicket.where(ticket_id: ticket.id)
    assert_equal true, archive_ticket.exists?
  ensure
    Account.current.rollback(:archive_on_missing_associations) unless @archive_missing_launched
  end

  def test_archive_ticket_missing_ticket_state_assoc_with_feature
    ticket = prepare_archive_ticket
    missing_field = Helpdesk::TicketState.find_by_ticket_id(ticket.id)
    missing_field.destroy
    ticket.reload
    enable_archive_on_missing_assoc
    convert_ticket_to_archive(ticket)
    archive_ticket = Helpdesk::ArchiveTicket.where(ticket_id: ticket.id)
    assert_equal true, archive_ticket.exists?
  ensure
    Account.current.rollback(:archive_on_missing_associations) unless @archive_missing_launched
  end

  def test_archive_ticket_missing_flexifield_assoc_with_feature
    ticket = prepare_archive_ticket
    missing_field = Flexifield.find_by_flexifield_set_id(ticket.id)
    missing_field.destroy
    ticket.reload
    enable_archive_on_missing_assoc
    convert_ticket_to_archive(ticket)
    archive_ticket = Helpdesk::ArchiveTicket.where(ticket_id: ticket.id)
    assert_equal true, archive_ticket.exists?
  ensure
    Account.current.rollback(:archive_on_missing_associations) unless @archive_missing_launched
  end

  def test_archive_ticket
    ticket = prepare_archive_ticket
    ticket.reload
    convert_ticket_to_archive(ticket)
    archive_ticket = Helpdesk::ArchiveTicket.where(ticket_id: ticket.id)
    assert_equal true, archive_ticket.exists?
  ensure
    cleanup_archive_ticket(ticket, {conversations: true})
  end

  private

  def prepare_archive_ticket
    ticket = create_ticket
    ticket.updated_at = TICKET_UPDATED_DATE
    ticket.status = 5
    ticket.save!
    ticket
  end

  def enable_archive_on_missing_assoc
    @archive_missing_launched = Account.current.launched?(:archive_on_missing_associations)
    Account.current.launch(:archive_on_missing_associations) unless @archive_missing_launched
  end

  def disable_archive_on_missing_assoc
    @archive_missing_launched = Account.current.launched?(:archive_on_missing_associations)
    Account.current.rollback(:archive_on_missing_associations) if @archive_missing_launched
  end
end
