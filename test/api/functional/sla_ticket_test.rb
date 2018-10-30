require_relative '../test_helper'
require 'sidekiq/testing'
require 'webmock/minitest'
['sla_test_helper'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
%w[account_test_helper.rb business_calendars_helper.rb].each { |file| require "#{Rails.root}/test/core/helpers/#{file}" }
['tickets_test_helper.rb'].each { |file| require "#{Rails.root}/test/api/helpers/#{file}" }
class TicketsControllerTest < ActionController::TestCase
  include TicketsTestHelper
  include SlaTestHelper
  include AccountTestHelper
  include BusinessCalendarsTestHelper
  @@before_all_run_sla = false
  def setup
    super
    before_all
  end

  def before_all
    return if @@before_all_run_sla
    create_test_account
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

end
