require_relative '../test_helper'
require_relative '../../../test/core/helpers/note_test_helper'
require_relative '../../api/sidekiq/create_ticket_helper'
require 'sidekiq/testing'
require 'webmock/minitest'
['sla_test_helper'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
%w[account_test_helper.rb business_calendars_helper.rb].each { |file| require "#{Rails.root}/test/core/helpers/#{file}" }
['tickets_test_helper.rb'].each { |file| require "#{Rails.root}/test/api/helpers/#{file}" }
class TicketsControllerTest < ActionController::TestCase
  include ApiTicketsTestHelper
  include SlaTestHelper
  include AccountTestHelper
  include BusinessCalendarsTestHelper
  include NoteTestHelper
  include CreateTicketHelper

  @@before_all_run_sla = false
  def setup
    super
    before_all
  end

  def before_all
    return if @@before_all_run_sla
    @account = create_test_account if @account.nil?
    @account.make_current
    @account.business_calendar.destroy_all
    @account.sla_policies.destroy_all
    @business_calendar = create_business_calendar(is_default: 1)
    @@before_all_run_sla = true
  end

  def teardown
    super
  end

  def wrap_cname(params = {})
    { ticket: params }
  end

  # ---  Business calender assumption for the test
  # :working_hours:
  #   1:
  #     :beginning_of_workday: 8:00 am
  #     :end_of_workday: 5:00 pm
  #   2:
  #     :beginning_of_workday: 8:00 am
  #     :end_of_workday: 5:00 pm
  #   3:
  #     :beginning_of_workday: 8:00 am
  #     :end_of_workday: 5:00 pm
  #   4:
  #     :beginning_of_workday: 8:00 am
  #     :end_of_workday: 5:00 pm
  #   5:
  #     :beginning_of_workday: 8:00 am
  #     :end_of_workday: 5:00 pm
  # :weekdays:
  # - 1
  # - 2
  # - 3
  # - 4
  # - 5
  # :fullweek: false
  #
  # Holidays
  # ---
  # - - Jan 16
  #   - Birthday of Martin Luther King Jr
  # - - Feb 20
  #   - "Washington\xE2\x80\x99s Birthday"
  # - - May 28
  #   - Memorial Day
  # - - Jul 04
  #   - Independence Day
  # - - Sep 03
  #   - Labor Day
  # - - Oct 08
  #   - Columbus Day
  # - - Nov 11
  #   - Veterans Day
  # - - Nov 22
  #   - Thanksgiving Day
  # - - Dec 25
  #   - Christmas Day
  # - - Jan 01
  #   - "New Year\xE2\x80\x99s Day"
  #

  def test_sla_due_by_fr_due_by
    skip('failures and errors 21')
    sla_policy
    freeze_time_now(get_datetime('9:00', '27 Aug 2018')) do
      params = ticket_params_hash_sla
      post :create, construct_params({}, params)
    end
    ticket = @account.tickets.last
    assert_equal get_datetime('14:00', '27 Aug 2018'), ticket.due_by
    assert_equal get_datetime('13:00', '27 Aug 2018'), ticket.frDueBy
  end
  
  def test_ticket_resolution_time_by_bhrs
    skip('failures and errors 21')
    sla_policy
    freeze_time_now(get_datetime('9:00', '27 Aug 2018')) do
      params = ticket_params_hash_sla
      post :create, construct_params({}, params)
    end
    ticket = @account.tickets.last
    freeze_time_now(get_datetime('10:00', '30 Aug 2018')) do
      params_hash = { status: 4 }
      put :update, construct_params({ id: ticket.display_id }, params_hash)
    end
    ticket.reload
    assert_equal ticket.ticket_states.resolution_time_by_bhrs, 100_800
  end

  def test_business_time_until_func
    # this senario wouln't come in our ticketing flow but still adding it
    Time.zone = @account.business_calendar.default.first.time_zone
    monday = get_datetime('10:00', '30 Aug 2018')
    assert_equal monday.business_time_until(get_datetime('9:00', '27 Aug 2018'), @business_calendar), -100_800
  end
  
  def test_business_time_until_func_invalid_holiday_dates
    # when business calender is corrupt
    BusinessCalendar.any_instance.stubs(:holiday_data).returns([["",""]])
    Time.zone = @account.business_calendar.default.first.time_zone
    monday = get_datetime('9:00', '27 Aug 2018')
    assert_equal monday.business_time_until(get_datetime('10:00', '30 Aug 2018'), @business_calendar), 100_800
    BusinessCalendar.any_instance.unstub(:holiday_data)
  end

  def test_nr_dueBy
    Account.current.stubs(:next_response_sla_enabled?).returns(true)
    sla_policy
    freeze_time_now(get_datetime('10:00', '5 Nov 2019')) do
      params = ticket_params_hash_sla
      post :create, construct_params({}, params)
    end
    ticket = @account.tickets.last
    assert_nil ticket.nr_due_by
    agent = add_agent(@account)
    freeze_time_now(get_datetime('11:00', '5 Nov 2019')) do
      params_hash = {
          ticket_id: ticket.id,
          user_id: agent.id,
          created_at: Time.zone.now
      }
      note = create_note params_hash
      ticket.current_note_id = note.id
      note.save_response_time
      ticket.update_dueby
      assert_equal ticket.first_response_time, get_datetime('11:00', '5 Nov 2019')
      assert_nil ticket.nr_due_by
      assert_nil ticket.last_customer_note_id
    end
    freeze_time_now(get_datetime('12:00', '5 Nov 2019')) do
      params_hash = {
          ticket_id: ticket.id,
          user_id: ticket.requester_id,
          created_at: Time.zone.now
      }
      note = create_note params_hash
      ticket.current_note_id = note.id
      note.save_response_time
      ticket.update_dueby
      assert_equal ticket.nr_due_by , note.created_at + 14400
      assert_equal note.id, ticket.last_customer_note_id
      assert_equal ticket.nr_updated_at, note.created_at
    end
    freeze_time_now(get_datetime('13:00', '5 Nov 2019')) do
      params_hash = {
          ticket_id: ticket.id,
          user_id: ticket.requester_id,
          created_at: Time.zone.now
      }
      note = create_note params_hash
      ticket.current_note_id = note.id
      note.save_response_time
      ticket.update_dueby
      assert_equal ticket.nr_due_by , note.created_at + 10800
      assert_not_nil ticket.last_customer_note_id
      assert_equal ticket.nr_updated_at, get_datetime('12:00', '5 Nov 2019')
      assert_not_equal note.id, ticket.last_customer_note_id
    end
    freeze_time_now(get_datetime('14:00', '5 Nov 2019')) do
      params_hash = {
          ticket_id: ticket.id,
          user_id: agent.id,
          created_at: Time.zone.now
      }
      note = create_note params_hash
      ticket.current_note_id = note.id
      note.save_response_time
      ticket.update_dueby
      assert_nil ticket.nr_due_by
      assert_nil ticket.last_customer_note_id
      assert_nil ticket.nr_updated_at
    end
  ensure
    Account.current.unstub(:next_response_sla_enabled?)
    ticket.destroy
  end

  def test_nr_dueBy_on_priority_change
    Account.current.stubs(:next_response_sla_enabled?).returns(true)
    sla_policy
    @note = nil
    freeze_time_now(get_datetime('10:00', '5 Nov 2019')) do
      params = ticket_params_hash_sla
      post :create, construct_params({}, params)
    end
    ticket = @account.tickets.last
    agent = add_agent(@account)
    freeze_time_now(get_datetime('10:15', '5 Nov 2019')) do
      params_hash = {
          ticket_id: ticket.id,
          user_id: agent.id,
          created_at: Time.zone.now
      }
      @note = create_note params_hash
      ticket.current_note_id = @note.id
      @note.save_response_time
      ticket.update_dueby
    end
    freeze_time_now(get_datetime('11:00', '5 Nov 2019')) do
      params_hash = {
          ticket_id: ticket.id,
          user_id: ticket.requester_id,
          created_at: Time.zone.now
      }
      @note = create_note params_hash
      ticket.current_note_id = @note.id
      @note.save_response_time
      ticket.update_dueby
      assert_equal @note.id, ticket.last_customer_note_id
      assert_equal ticket.nr_due_by, get_datetime('15:00', '5 Nov 2019')
    end
    freeze_time_now(get_datetime('12:00', '5 Nov 2019')) do
      params_hash = { priority: 4 }
      put :update, construct_params({ id: ticket.display_id }, params_hash)
      ticket.reload
      ticket.update_dueby
      ticket.update_on_state_time
      @note.reload
      assert_nil ticket.nr_due_by
      assert_equal @note.id, ticket.last_customer_note_id
      assert_equal 3600, @note.on_state_time
    end
  ensure
    Account.current.unstub(:next_response_sla_enabled?)
    ticket.destroy
  end

  def test_nr_dueBy_on_sla_timer_toggle
    Account.current.stubs(:next_response_sla_enabled?).returns(true)
    sla_policy
    freeze_time_now(get_datetime('14:00', '5 Nov 2019')) do
      params = ticket_params_hash_sla
      post :create, construct_params({}, params)
    end
    ticket = @account.tickets.last
    agent = add_agent(@account)
    freeze_time_now(get_datetime('14:30', '5 Nov 2019')) do
      params_hash = {
          ticket_id: ticket.id,
          user_id: agent.id,
          created_at: Time.zone.now
      }
      note = create_note params_hash
      ticket.current_note_id = note.id
      note.save_response_time
      ticket.update_dueby
    end
    freeze_time_now(get_datetime('15:00', '5 Nov 2019')) do
      params_hash = {
          ticket_id: ticket.id,
          user_id: ticket.requester_id,
          created_at: Time.zone.now
      }
      note = create_note params_hash
      ticket.current_note_id = note.id
      note.save_response_time
      ticket.update_dueby
      assert_equal ticket.nr_due_by, get_datetime('10:00', '6 Nov 2019')
    end
    freeze_time_now(get_datetime('9:00', '6 Nov 2019')) do
      params_hash = { status: 3 }
      put :update, construct_params({ id: ticket.display_id }, params_hash)
      ticket.update_dueby
      ticket.update_on_state_time
    end
    freeze_time_now(get_datetime('9:30', '6 Nov 2019')) do
      params_hash = {
          ticket_id: ticket.id,
          user_id: ticket.requester_id,
          created_at: Time.zone.now
      }
      note = create_note params_hash
      ticket.current_note_id = note.id
      note.save_response_time
      ticket.update_dueby
      assert ticket.last_customer_note_id.present?
      assert_not_equal note.id, ticket.last_customer_note_id
      assert_equal ticket.nr_due_by, get_datetime('10:00', '6 Nov 2019')
    end
    ticket.nr_due_by = get_datetime('11:00', '6 Nov 2019')
    freeze_time_now(get_datetime('10:30', '6 Nov 2019')) do
      params_hash = { status: 3 }
      put :update, construct_params({ id: ticket.display_id }, params_hash)
      ticket.update_dueby
      ticket.update_on_state_time
    end
    freeze_time_now(get_datetime('10:40', '6 Nov 2019')) do
      params_hash = {
          ticket_id: ticket.id,
          user_id: agent.id,
          created_at: Time.zone.now,
          private: true
      }
      note = create_note params_hash
      ticket.current_note_id = note.id
      note.save_response_time
      ticket.update_dueby
      assert_equal ticket.nr_due_by, get_datetime('11:00', '6 Nov 2019')
      assert_not_nil ticket.last_customer_note_id
    end
    freeze_time_now(get_datetime('10:50', '6 Nov 2019')) do
      params_hash = {
          ticket_id: ticket.id,
          user_id: agent.id,
          created_at: Time.zone.now
      }
      note = create_note params_hash
      ticket.current_note_id = note.id
      note.save_response_time
      ticket.update_dueby
      assert_nil ticket.nr_due_by
      assert_nil ticket.last_customer_note_id
    end
  ensure
    Account.current.unstub(:next_response_sla_enabled?)
    ticket.destroy
  end

  def test_nr_dueBy_off_sla_timer
    Account.current.stubs(:next_response_sla_enabled?).returns(true)
    Account.any_instance.stubs(:time_zone).returns('Edinburgh')
    sla_policy
    @note = nil
    freeze_time_now(get_datetime('10:00', '5 Nov 2019')) do
      params = ticket_params_hash_sla
      post :create, construct_params({}, params)
    end
    ticket = @account.tickets.last
    agent = add_agent(@account)
    freeze_time_now(get_datetime('11:00', '5 Nov 2019')) do
      params_hash = {
          ticket_id: ticket.id,
          user_id: agent.id,
          created_at: Time.zone.now
      }
      @note = create_note params_hash
      ticket.current_note_id = @note.id
      @note.save_response_time
      ticket.update_dueby
    end
    freeze_time_now(get_datetime('11:30', '5 Nov 2019')) do
      params_hash = { status: 3 }
      put :update, construct_params({ id: ticket.display_id }, params_hash)
      ticket.update_dueby
      ticket.update_on_state_time
    end
    freeze_time_now(get_datetime('12:00', '5 Nov 2019')) do
      params_hash = {
          ticket_id: ticket.id,
          user_id: ticket.requester_id,
          created_at: Time.zone.now
      }
      @note = create_note params_hash
      ticket.current_note_id = @note.id
      @note.save_response_time
      ticket.update_dueby
      assert_equal @note.id, ticket.last_customer_note_id
    end
    freeze_time_now(get_datetime('12:30', '5 Nov 2019')) do
      params_hash = {
          ticket_id: ticket.id,
          user_id: agent.id,
          created_at: Time.zone.now
      }
      @note = create_note params_hash
      ticket.current_note_id = @note.id
      p "ticket.nr_due_by :: #{ticket.nr_due_by.inspect}"
      p "get_datetime('12:30', '5 Nov 2019') :: #{get_datetime('12:30', '5 Nov 2019').inspect}"
      @note.save_response_time
      ticket.update_dueby
      p "ticket.nr_due_by :: #{ticket.nr_due_by.inspect}"
      p "get_datetime('12:30', '5 Nov 2019') :: #{get_datetime('12:30', '5 Nov 2019').inspect}"
      assert_nil ticket.nr_due_by
      assert_nil ticket.last_customer_note_id
    end
    freeze_time_now(get_datetime('12:45', '5 Nov 2019')) do
      params_hash = {
          ticket_id: ticket.id,
          user_id: ticket.requester_id,
          created_at: Time.zone.now
      }
      @note = create_note params_hash
      ticket.current_note_id = @note.id
      p "ticket.nr_due_by :: #{ticket.nr_due_by.inspect}"
      p "get_datetime('12:45', '5 Nov 2019') :: #{get_datetime('12:45', '5 Nov 2019').inspect}"
      @note.save_response_time
      ticket.update_dueby
      p "ticket.nr_due_by :: #{ticket.nr_due_by.inspect}"
      p "get_datetime('12:45', '5 Nov 2019') :: #{get_datetime('12:45', '5 Nov 2019').inspect}"
      assert_equal @note.id, ticket.last_customer_note_id
    end
    freeze_time_now(get_datetime('12:50', '5 Nov 2019')) do
      params_hash = {
          ticket_id: ticket.id,
          user_id: ticket.requester_id,
          created_at: Time.zone.now
      }
      @note = create_note params_hash
      p "ticket.nr_due_by :: #{ticket.nr_due_by.inspect}"
      p "get_datetime('12:50', '5 Nov 2019') :: #{get_datetime('12:50', '5 Nov 2019').inspect}"
      @note.save_response_time
      ticket.update_dueby
      p "ticket.nr_due_by :: #{ticket.nr_due_by.inspect}"
      p "get_datetime('12:50', '5 Nov 2019') :: #{get_datetime('12:50', '5 Nov 2019').inspect}"
      assert_not_nil ticket.last_customer_note_id
      assert_not_equal @note.id, ticket.last_customer_note_id
    end
    freeze_time_now(get_datetime('13:00', '5 Nov 2019')) do
      params_hash = { status: 2 }
      p "ticket.nr_due_by :: #{ticket.nr_due_by.inspect}"
      p "get_datetime('16:00', '5 Nov 2019') :: #{get_datetime('16:00', '5 Nov 2019').inspect}"
      put :update, construct_params({ id: ticket.display_id }, params_hash)
      ticket.update_dueby
      ticket.update_on_state_time
      p "Time.zone :: #{Time.zone}"
      p "@account.time_zone :: #{@account.time_zone}"
      p "ticket.nr_due_by :: #{ticket.nr_due_by.inspect}"
      p "get_datetime('16:00', '5 Nov 2019') :: #{get_datetime('16:00', '5 Nov 2019').inspect}"
      assert_equal ticket.nr_due_by, get_datetime('16:00', '5 Nov 2019')
    end
  ensure
    Account.current.unstub(:next_response_sla_enabled?)
    Account.any_instance.unstub(:time_zone)
    ticket.destroy
  end
end