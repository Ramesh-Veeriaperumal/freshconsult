require_relative '../../test_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!

class Archive::TicketsControllerTest < ActionController::TestCase
  include ArchiveTicketTestHelper
  include TicketsTestHelper
  include TicketHelper

  ARCHIVE_DAYS = 120
  TICKET_UPDATED_DATE = 150.days.ago
  ARCHIVE_TICKETS_COUNT = 5
  EXCLUDE_ATTRIBUTES_FOR_SHOW = [:email_config_id, :association_type].freeze

  def setup
    super
    @account.make_current
    @account.enable_ticket_archiving(ARCHIVE_DAYS)
    Sidekiq::Worker.clear_all
    @account.features.send(:archive_tickets).create
    create_archive_ticket_with_assoc(
      created_at: TICKET_UPDATED_DATE,
      updated_at: TICKET_UPDATED_DATE,
      create_association: true
    )
  end

  def teardown
    cleanup_archive_ticket(@archive_ticket, {conversations: true})
  end

  def test_show
    stub_archive_assoc_for_show(@archive_association) do
      archive_ticket = @account.archive_tickets.find_by_ticket_id( @archive_ticket.id)
      return if archive_ticket.blank?

      get :show, controller_params(id: archive_ticket.display_id, include: 'stats')
      assert_response 200

      ticket_pattern = ticket_pattern_for_show(archive_ticket)
      match_json(ticket_pattern)
    end
  end

  def test_show_with_empty_conversations
    stub_archive_assoc_for_show(@archive_association) do
      archive_ticket = @account.archive_tickets.find_by_ticket_id( @archive_ticket.id)
      return if archive_ticket.blank?

      get :show, controller_params(id: archive_ticket.display_id, include: 'stats,conversations')
      assert_response 200

      ticket_pattern = ticket_pattern_for_show(archive_ticket)
      ticket_pattern['conversations'] = []
      match_json(ticket_pattern)
    end
  end

  def test_show_with_requester
    stub_archive_assoc_for_show(@archive_association) do
      archive_ticket = @account.archive_tickets.find_by_ticket_id( @archive_ticket.id)
      return if archive_ticket.blank?

      get :show, controller_params(id: archive_ticket.display_id, include: 'stats,requester')
      assert_response 200

      ticket_pattern = ticket_pattern_for_show(archive_ticket, [:requester])
      match_json(ticket_pattern)
    end
  end

  def test_show_without_ticket
    get :show, controller_params(id: 'x')
    assert_response 404
  end

  def test_show_without_permission
    stub_archive_assoc_for_show(@archive_association) do
      User.any_instance.stubs(:has_ticket_permission?).returns(false)
      archive_ticket = @account.archive_tickets.find_by_ticket_id( @archive_ticket.id)
      get :show, controller_params(id: archive_ticket.display_id)
      User.any_instance.unstub(:has_ticket_permission?)
      assert_response 403
      match_json(request_error_pattern(:access_denied))
    end
  end

  def test_show_with_invalid_params
    stub_archive_assoc_for_show(@archive_association) do
      archive_ticket = @account.archive_tickets.find_by_ticket_id( @archive_ticket.id)
      return if archive_ticket.blank?

      get :show, controller_params(id: archive_ticket.display_id, include: 'invalid')
      assert_response 400
    end
  end

  def test_without_archive_feature
    @account.features.archive_tickets.destroy
    get :show, controller_params(id: 1)
    assert_response 403
  end

  def test_worker_archive_delete_initialise
    stub_archive_assoc_for_show(@archive_association) do
      archive_ticket = @account.archive_tickets.find_by_ticket_id(@archive_ticket.id)
      no_of_jobs = ::Archive::DeleteArchiveTicket.jobs.size
      delete :destroy, controller_params(id: archive_ticket.display_id)
      current_jobs = ::Archive::DeleteArchiveTicket.jobs.size
      assert_equal no_of_jobs + 1, current_jobs
      assert_response 204
    end
  end

  def test_worker_archive_delete_without_ticket
    no_of_jobs = ::Archive::DeleteArchiveTicket.jobs.size
    delete :destroy, controller_params(id: 'q')
    current_jobs = ::Archive::DeleteArchiveTicket.jobs.size
    assert_equal no_of_jobs, current_jobs
    assert_response 404
  end

  def test_delete_without_permission
    stub_archive_assoc_for_show(@archive_association) do
      User.any_instance.stubs(:has_ticket_permission?).returns(false)
      no_of_jobs = ::Archive::DeleteArchiveTicket.jobs.size
      archive_ticket = @account.archive_tickets.find_by_ticket_id( @archive_ticket.id)
      get :destroy, controller_params(id: archive_ticket.display_id)
      current_jobs = ::Archive::DeleteArchiveTicket.jobs.size
      User.any_instance.unstub(:has_ticket_permission?)
      assert_equal no_of_jobs, current_jobs
      assert_response 403
      match_json(request_error_pattern(:access_denied))
    end
  end


  private

    def update_ticket_attributes(pattern, changes = {})
      changes.each do |k, v|
        pattern[k] = v
      end
      pattern
    end

    def exclude_ticket_attributes(pattern, exclude = [])
      exclude.each do |key|
        pattern.except!(key)
      end
      pattern
    end

    def ticket_pattern_for_show(archive_ticket, include_params = nil)
      ticket_pattern = show_ticket_pattern({
                                             cc_emails: archive_ticket.cc_email['cc_emails'],
                                             description: archive_ticket.description_html,
                                             description_text: archive_ticket.description,
                                             custom_fields: custom_fields(archive_ticket)
                                           }, @archive_ticket)
      changes = {
        created_at: archive_ticket.created_at,
        updated_at: archive_ticket.updated_at,
        archived: true,
        due_by: @archive_ticket.due_by.to_datetime.try(:utc).to_s,
        fr_due_by: @archive_ticket.frDueBy.to_datetime.try(:utc).to_s
      }
      ticket_pattern = update_ticket_attributes(ticket_pattern, changes)
      ticket_pattern = exclude_ticket_attributes(ticket_pattern, EXCLUDE_ATTRIBUTES_FOR_SHOW)
      ticket_pattern[:stats] = ticket_states_pattern(archive_ticket.ticket_states, archive_ticket.status)
      ticket_pattern.merge!(include_json(archive_ticket, include_params)) if include_params.present?

      ticket_pattern
    end

    def include_json(ticket, params)
      final_json = {}
      final_json[:requester] =  requester_hash(ticket) if params.include? :requester
      final_json
    end

    def requester_hash(ticket, options={})
      if defined?($infra) && $infra['PRIVATE_API']
        options[:sideload_options] = ['company'] if @account.multiple_user_companies_enabled?
        ContactDecorator.new(ticket.requester, options).requester_hash
      else
        requester_pattern(ticket.requester)
      end
    end

    def custom_fields archive_ticket
      custom_fields_hash = {}
      archive_ticket.custom_field.each do |k,v|
        column = Archive::TicketDecorator.display_name(k)
        custom_fields_hash[column] = v
      end
      custom_fields_hash
    end
end
