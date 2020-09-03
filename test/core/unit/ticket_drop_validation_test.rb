require_relative '../test_helper'

require Rails.root.join('spec', 'support', 'ticket_helper.rb')

class TicketDropValidationTest < ActiveSupport::TestCase

include AccountTestHelper
include TicketHelper
include ::Admin::AdvancedTicketing::FieldServiceManagement::Util

  def setup
    current_account
    perform_fsm_operations
    create_canned_form
  end

  def teardown
    cleanup_fsm
  end

  # Validate dynamic liquid method - Using valid liquid method name
  # Eg: canned_form_6. 
  # Returns true if the given method is valid & already defined.

  def test_validate_dynamic_liquid_method
    td = Helpdesk::TicketDrop.new(@account.tickets.first)
    test_liquid_method = "canned_form_1"
    result = td.dynamic_liquid_method?(test_liquid_method)
    assert_equal(result, true)
  end

  # Validate dynamic liquid method - Using invalid liquid method
  # Eg: asdf_7. 
  # Returns false if the given method is not valid or undefined.

  def test_validate_dynamic_liquid_method_using_invalid_method
    td = Helpdesk::TicketDrop.new(@account.tickets.first)
    test_liquid_method = "asdf_7"
    result = td.dynamic_liquid_method?(test_liquid_method)
    assert_equal(result, false)
  end

  # Validate dynamic liquid method - Using invalid input
  # Eg: canned_form_canned_form_6

  def test_validate_dynamic_liquid_method_with_typo
    td = Helpdesk::TicketDrop.new(@account.tickets.first)
    test_liquid_method = "canned_form_canned_form_1"
    result = td.dynamic_liquid_method?(test_liquid_method)
    assert_equal(result, false)
  end

  # Fetch the canned form url from the given canned form ID
  # Given an ticket & canned form ID, returns an URL

  def test_fetch_canned_form_url
    ticket = @account.tickets.first
    td = Helpdesk::TicketDrop.new(ticket)
    cf_id = 1
    result = td.canned_form(cf_id)
    assert(result.present?)
  end

  def test_cf_fsm_appointment_start_time
    time = Time.now.utc
    ticket = create_service_task_ticket(fsm_contact_name: 'User', fsm_service_location: 'Location', fsm_phone_number: '9912345678',
                                        fsm_appointment_start_time: time.iso8601, fsm_appointment_end_time: (Time.now + 1.hour).utc.iso8601)
    new_time = time.in_time_zone(@account.time_zone).strftime('%B %e %Y at %I:%M %p %Z')
    td = Helpdesk::TicketDrop.new(ticket)
    result = td.cf_fsm_appointment_start_time
    assert(result, new_time)
  end

  def test_cf_fsm_appointment_end_time
    time = (Time.now + 1.hour).utc
    ticket = create_service_task_ticket(fsm_contact_name: 'User', fsm_service_location: 'Location', fsm_phone_number: '9912345678',
                                        fsm_appointment_start_time: Time.now.utc.iso8601, fsm_appointment_end_time: time.iso8601)
    new_time = time.in_time_zone(@account.time_zone).strftime('%B %e %Y at %I:%M %p %Z')
    td = Helpdesk::TicketDrop.new(ticket)
    result = td.cf_fsm_appointment_end_time
    assert(result, new_time)
  end

  # Verify the functionality of using the existing canned form handle if the previous is unused

  def test_use_existing_canned_form
    ticket = @account.tickets.first
    td = Helpdesk::TicketDrop.new(ticket)
    cf_id = 1
    latest_cf_handle = @account.canned_forms.find(cf_id).canned_form_handles.where(ticket_id: ticket.id).last
    if latest_cf_handle.nil?
      latest_cf_handle = @account.canned_forms.find(cf_id).canned_form_handles.create(ticket_id: ticket.id)
    end
    token_id = latest_cf_handle.id_token
    result = td.canned_form(cf_id)
    assert(result.include? token_id)
  end

  # Verify the creation of canned form handle - create new handle if the previous handle is used.

  def test_create_canned_form
    ticket = @account.tickets.last
    td = Helpdesk::TicketDrop.new(ticket)
    cf_id = 1
    latest_cf_handle = @account.canned_forms.find(cf_id).canned_form_handles.where(ticket_id: ticket.id).last
    if latest_cf_handle.nil?
      latest_cf_handle = @account.canned_forms.find(cf_id).canned_form_handles.create(ticket_id: ticket.id)
    end
      latest_cf_handle[:response_note_id] = 10 
      latest_cf_handle.save!
    token_id = latest_cf_handle.id_token
    result = td.canned_form(cf_id)
    assert(result.exclude? token_id )
  end

  private
  def current_account
    if @account.nil?
      create_test_account
    end
    @account.make_current
  end

  def create_canned_form
    @account.canned_forms.create(:name => "Test Canned Form")
  end

end