require_relative '../../test_helper.rb'
%w[business_calendars_helper.rb].each { |file| require "#{Rails.root}/test/core/helpers/#{file}" }
require Rails.root.join('test', 'api', 'helpers', 'admin', 'api_business_calendar_helper.rb')
class Admin::ApiBusinessCalendarsControllerTest < ActionController::TestCase
  include BusinessHoursTestHelper
  include Admin::ApiBusinessCalendarHelper
  include BusinessCalendarsTestHelper

  def setup
    super
    Account.stubs(:current).returns(Account.last)
    User.stubs(:current).returns(User.first)
    Account.any_instance.stubs(:multiple_business_hours_enabled?).returns(true)
  end

  def teardown
    Account.current.business_calendar.where(name: 'Dark web with social engineering').each(&:destroy)
    Account.unstub(:current)
    User.unstub(:current)
    Account.any_instance.unstub(:multiple_business_hours_enabled?)
  end

  def wrap_cname(params)
    { api_business_calendar: params }
  end

  def test_index_business_hour
    enable_emberize_business_hours do
      bcs = []
      2.times do
        bcs.push(create_business_calendar)
      end
      get :index, controller_params
      pattern = []
      Account.current.business_calendar.order(:name).each do |bc|
        pattern << ember_business_hour_index_pattern(bc)
      end
      assert_response 200
      match_json(pattern.ordered!)
      bcs.each(&:destroy)
    end
  end

  def test_index_business_hour_with_pagination
    enable_emberize_business_hours do
      bcs = []
      Account.current.business_calendar.where(is_default: false).each(&:destroy)
      3.times do
        bcs.push(create_business_calendar)
      end
      get :index, controller_params(page: 1)
      assert JSON.parse(response.body).count == Account.current.business_calendar.count
      bcs.each(&:destroy)
    end
  end

  def test_index_without_enabling_feature
    get :index, controller_params
    assert_response 403
  end

  def test_index_business_hour_without_multiple_business_hours
    enable_emberize_business_hours do
      Account.any_instance.stubs(:multiple_business_hours_enabled?).returns(false)
      get :index, controller_params
      pattern = []
      Account.current.business_calendar.order(:name).where(is_default: true).each do |bc|
        pattern << ember_business_hour_index_pattern(bc)
      end
      assert_response 200
      match_json(pattern.ordered!)
      Account.any_instance.stubs(:multiple_business_hours_enabled?).returns(true)
    end
  end

  def test_show_without_enabling_feature
    business_calendar = create_business_calendar
    get :show, controller_params(id: business_calendar.id)
    assert_response 403
  end

  def test_show_ember_business_hour
    enable_emberize_business_hours do
      business_calendar = create_business_calendar
      get :show, controller_params(id: business_calendar.id)
      response = JSON.parse(@response.body)
      assert_response 200
      match_json(ember_business_hour_show_pattern(business_calendar))
      business_calendar.destroy
    end
  end

  def test_show_ember_business_hour_with_invalid_id
    enable_emberize_business_hours do
      business_calendar_id = 32_424_322
      business_calendar = Account.current.business_calendar.where(id: business_calendar_id).first
      skip if business_calendar
      get :show, controller_params(id: business_calendar_id)
      assert_response 404
    end
  end

  def test_update_name_in_ember_business_calendar
    enable_emberize_business_hours do
      business_calendar = create_business_calendar
      update_params = { name: 'indian calendar' }
      put :update, construct_params({ id: business_calendar.id }, update_params)
      response = JSON.parse(@response.body)
      assert_response 200
      business_calendar = business_calendar.reload
      match_json(ember_business_hour_show_pattern(business_calendar))
      business_calendar.destroy
    end
  end

  def test_update_timezone_with_business_calendar
    enable_emberize_business_hours do
      business_calendar = create_business_calendar
      update_params = { time_zone: 'hawaii' }
      put :update, construct_params({ id: business_calendar.id }, update_params)
      assert_response 200
      business_calendar = business_calendar.reload
      match_json(ember_business_hour_show_pattern(business_calendar))
      business_calendar.destroy
    end
  end

  def test_update_description_with_business_calendar
    enable_emberize_business_hours do
      business_calendar = create_business_calendar
      update_params = { description: 'Its indian calendar' }
      put :update, construct_params({ id: business_calendar.id }, update_params)
      assert_response 200
      business_calendar = business_calendar.reload
      match_json(ember_business_hour_show_pattern(business_calendar))
      business_calendar.destroy
    end
  end

  def test_update_holidays_in_business_calendar
    enable_emberize_business_hours do
      business_calendar = create_business_calendar
      update_params = { holidays: [{ name: 'Test day1', date: 'Jan 1' }, { name: 'Test day2', date: 'Jan 3' }] }
      put :update, construct_params({ id: business_calendar.id }, update_params)
      assert_response 200
      business_calendar = business_calendar.reload
      match_json(ember_business_hour_show_pattern(business_calendar))
      business_calendar.destroy
    end
  end

  def test_update_24_by_7_channel_business_hours
    enable_emberize_business_hours do
      business_calendar = create_business_calendar
      update_params = { channel_business_hours: [{ channel: 'ticket', business_hours_type: '24_7_availability' }] }
      put :update, construct_params({ id: business_calendar.id }, update_params)
      assert_response 200
      business_calendar = business_calendar.reload
      match_json(ember_business_hour_show_pattern(business_calendar))
      business_calendar.destroy
    end
  end

  def test_update_custom_channel_business_hours
    enable_emberize_business_hours do
      business_calendar = create_business_calendar
      update_params = { channel_business_hours: [{ channel: 'ticket', business_hours_type: 'custom', business_hours: [{ day: 'monday', time_slots: [{ start_time: '08:00', end_time: '17:00' }] }] }] }
      put :update, construct_params({ id: business_calendar.id }, update_params)
      assert_response 200
      business_calendar = business_calendar.reload
      match_json(ember_business_hour_show_pattern(business_calendar))
      business_calendar.destroy
    end
  end

  def test_update_with_blank_channel_business_hours
    enable_emberize_business_hours do
      business_calendar = create_business_calendar
      update_params = { channel_business_hours: [] }
      put :update, construct_params({ id: business_calendar.id }, update_params)
      assert_response 400
      match_json([bad_request_error_pattern('channel_business_hours', "can't be blank", code: :invalid_value)])
      business_calendar.destroy
    end
  end

  def test_update_custom_channel_business_hours_without_channel_name
    enable_emberize_business_hours do
      business_calendar = create_business_calendar
      update_params = { channel_business_hours: [{ business_hours_type: 'custom', business_hours: [{ day: 'monday', time_slots: [{ start_time: '08:00', end_time: '17:00' }] }] }] }
      put :update, construct_params({ id: business_calendar.id }, update_params)
      assert_response 400
      match_json([bad_request_error_pattern_with_nested_field('channel_business_hours', 'channel', 'It should be a/an String', code: :missing_field)])
      business_calendar.destroy
    end
  end

  def test_update_custom_channel_business_hours_without_business_hours_type
    enable_emberize_business_hours do
      business_calendar = create_business_calendar
      update_params = { channel_business_hours: [{ channel: 'ticket', business_hours: [{ day: 'monday', time_slots: [{ start_time: '08:00', end_time: '17:00' }] }] }] }
      put :update, construct_params({ id: business_calendar.id }, update_params)
      assert_response 400
      match_json([bad_request_error_pattern_with_nested_field('channel_business_hours', 'business_hours_type', 'It should be a/an String', code: :missing_field)])
      business_calendar.destroy
    end
  end

  def test_update_without_start_date_in_time_slots
    enable_emberize_business_hours do
      business_calendar = create_business_calendar
      update_params = { channel_business_hours: [{ channel: 'ticket', business_hours_type: 'custom', business_hours: [{ day: 'monday', time_slots: [{ end_time: '17:00' }] }] }] }
      put :update, construct_params({ id: business_calendar.id }, update_params)
      assert_response 400
      match_json([bad_request_error_pattern('channel_business_hours[:business_hours][:time_slots]', "It should be one of these values: 'start_time, end_time'", code: :invalid_value)])
      business_calendar.destroy
    end
  end

  def test_update_without_day_in_time_slots
    enable_emberize_business_hours do
      business_calendar = create_business_calendar
      update_params = { channel_business_hours: [{ channel: 'ticket', business_hours_type: 'custom', business_hours: [{ time_slots: [{ end_time: '17:00' }] }] }] }
      put :update, construct_params({ id: business_calendar.id }, update_params)
      assert_response 400
      match_json([bad_request_error_pattern('channel_business_hour[:business_hours]', "It should be one of these values: 'day, time_slots'", code: :invalid_value)])
      business_calendar.destroy
    end
  end

  def test_update_channel_business_hours_with_wrong_time
    enable_emberize_business_hours do
      business_calendar = create_business_calendar
      update_params = { channel_business_hours: [{ channel: 'ticket', business_hours_type: 'custom', business_hours: [{ day: 'monday', time_slots: [{ start_time: '25:00', end_time: '17:00' }] }] }] }
      put :update, construct_params({ id: business_calendar.id }, update_params)
      assert_response 400
      match_json([bad_request_error_pattern('channel_business_hours[:business_hours][:time_slots][:start_time/end_time]', 'Please enter a valid time slot', code: :invalid_value)])
      business_calendar.destroy
    end
  end

  def test_update_holidays_in_business_calendar_with_invalid_format
    enable_emberize_business_hours do
      business_calendar = create_business_calendar
      update_params = { holidays: [{ name: 'Test day1', date: 'Jan 1' }, { date: 'Jan 3' }] }
      put :update, construct_params({ id: business_calendar.id }, update_params)
      assert_response 400
      match_json([bad_request_error_pattern_with_nested_field('holidays', 'name', 'It should be a/an String', code: :missing_field)])
      business_calendar.destroy
    end
  end
  
  def test_destroy_ember_business_hour
    enable_emberize_business_hours do
      business_calendar = create_business_calendar
      delete :destroy, controller_params(id: business_calendar.id)
      assert_response 204
    end
  end

  def test_destroy_business_hour_without_enabling_feature
    business_calendar = create_business_calendar
    delete :destroy, controller_params(id: business_calendar.id)
    assert_response 403
    business_calendar.destroy
  end

  def test_destroy_default_ember_business_hour
    enable_emberize_business_hours do
      business_calendar = Account.current.business_calendar.where(is_default: true).first
      skip unless business_calendar
      delete :destroy, controller_params(id: business_calendar.id)
      assert_response 400
      match_json([bad_request_error_pattern(:id, :default_business_hour_destroy_not_allowed, code: :invalid_value)])
    end
  end

  def test_create_business_calendar
    enable_emberize_business_hours do
      params = dummy_business_calendar_default_params.merge('channel_business_hours' => dummy_channel_business_hours).merge(dummy_holiday_data)
      params['channel_business_hours'].first.merge!(dummy_business_hours_data)
      post :create, construct_params(params)
      assert_response 201
      created_business_calendar = Account.current.business_calendar.where(name: 'Dark web with social engineering').first
      match_json(ember_business_hours_create_pattern(created_business_calendar, params.with_indifferent_access))
    end
  end

  def test_create_business_calendar_holiday_data_nil
    enable_emberize_business_hours do
      params = dummy_business_calendar_default_params.merge('channel_business_hours' => dummy_channel_business_hours)
      params['channel_business_hours'].first.merge!(dummy_business_hours_data)
      post :create, construct_params(params)
      assert_response 201
      created_business_calendar = Account.current.business_calendar.where(name: 'Dark web with social engineering').first
      match_json(ember_business_hours_create_pattern(created_business_calendar, params.merge(holidays: []).with_indifferent_access))
    end
  end

  def test_create_business_calendar_holiday_data_empty_array
    enable_emberize_business_hours do
      params = dummy_business_calendar_default_params.merge('channel_business_hours' => dummy_channel_business_hours).merge('holidays' => [])
      params['channel_business_hours'].first.merge!(dummy_business_hours_data)
      post :create, construct_params(params)
      assert_response 201
      created_business_calendar = Account.current.business_calendar.where(name: 'Dark web with social engineering').first
      match_json(ember_business_hours_create_pattern(created_business_calendar, params.merge(holidays: []).with_indifferent_access))
    end
  end

  def test_create_business_calendar_with_holiday_having_invalid_date
    enable_emberize_business_hours do
      params = dummy_business_calendar_default_params.merge('channel_business_hours' => dummy_channel_business_hours)
                                                     .merge('holidays' => [{ "date": 'Feb 30', "name": 'feb 31 holiday' }])
      params['channel_business_hours'].first.merge!(dummy_business_hours_data)
      post :create, construct_params(params)
      error_data = [bad_request_error_pattern(:"holidays[:date]",
                                              'Day should be from 1 to 29 inclusive in {D, DD} format',
                                              code: 'invalid_value')]
      assert_response 400
      match_json(description: 'Validation failed', errors: error_data)
    end
  end

  def test_create_business_calendar_with_holiday_having_string_date
    enable_emberize_business_hours do
      params = dummy_business_calendar_default_params.merge('channel_business_hours' => dummy_channel_business_hours)
                                                     .merge('holidays' => [{ "date": 'Feb 30rt', "name": 'feb 31 holiday' }])
      params['channel_business_hours'].first.merge!(dummy_business_hours_data)
      post :create, construct_params(params)
      error_data = [bad_request_error_pattern(:"holidays[:date]",
                                              'Day should be from 1 to 29 inclusive in {D, DD} format',
                                              code: 'invalid_value')]
      assert_response 400
      match_json(description: 'Validation failed', errors: error_data)
    end
  end

  def test_create_business_calendar_with_holiday_having_wrong_month
    enable_emberize_business_hours do
      params = dummy_business_calendar_default_params.merge('channel_business_hours' => dummy_channel_business_hours)
                                                     .merge('holidays' => [{ "date": 'Aps 30', "name": 'feb 31 holiday' }])
      params['channel_business_hours'].first.merge!(dummy_business_hours_data)
      post :create, construct_params(params)
      error_data = [bad_request_error_pattern(:"holidays[:date]",
                                              "It should be one of these values: 'Jan, Feb, Mar, Apr, May, Jun, Jul, Aug, Sep, Oct, Nov, Dec'",
                                              code: 'invalid_value')]
      assert_response 400
      match_json(description: 'Validation failed', errors: error_data)
    end
  end

  def test_create_business_calendar_with_holiday_having_wrong_day_in_month
    enable_emberize_business_hours do
      params = dummy_business_calendar_default_params.merge('channel_business_hours' => dummy_channel_business_hours)
                                                     .merge('holidays' => [{ "date": 'Apr 031', "name": 'feb 31 holiday' }])
      params['channel_business_hours'].first.merge!(dummy_business_hours_data)
      post :create, construct_params(params)
      error_data = [bad_request_error_pattern(:"holidays[:date]",
                                              'Day should be from 1 to 30 inclusive in {D, DD} format',
                                              code: 'invalid_value')]
      assert_response 400
      match_json(description: 'Validation failed', errors: error_data)
    end
  end

  def test_create_business_calendar_with_holiday_having_wrongcase_month
    enable_emberize_business_hours do
      params = dummy_business_calendar_default_params.merge('channel_business_hours' => dummy_channel_business_hours)
                                                     .merge('holidays' => [{ "date": 'apr 30', "name": 'feb 31 holiday' }])
      params['channel_business_hours'].first.merge!(dummy_business_hours_data)
      post :create, construct_params(params)
      error_data = [bad_request_error_pattern(:"holidays[:date]",
                                              "It should be one of these values: 'Jan, Feb, Mar, Apr, May, Jun, Jul, Aug, Sep, Oct, Nov, Dec'",
                                              code: 'invalid_value')]
      assert_response 400
      match_json(description: 'Validation failed', errors: error_data)
    end
  end

  def test_create_business_calendar_24x7_availability
    enable_emberize_business_hours do
      params = dummy_business_calendar_default_params.merge('channel_business_hours' => dummy_channel_business_hours('ticket', '24_7_availability'))
      post :create, construct_params(params)
      assert_response 201
      created_business_calendar = Account.current.business_calendar.where(name: 'Dark web with social engineering').first
      match_json(ember_business_hours_create_pattern(created_business_calendar, params.merge(holidays: []).with_indifferent_access))
    end
  end

  def test_create_business_calendar_24x7_availability_business_hours_present
    enable_emberize_business_hours do
      params = dummy_business_calendar_default_params.merge('channel_business_hours' => dummy_channel_business_hours('ticket', '24_7_availability'))
      params['channel_business_hours'].first.merge!(dummy_business_hours_data)
      post :create, construct_params(params)
      error_data = [bad_request_error_pattern(:"channel_business_hours[24_7_availability]",
                                              "Parameter 'business_hours' is not allowed for 'channel_business_hours[24_7_availability]'",
                                              code: 'invalid_value')]
      assert_response 400
      match_json(description: 'Validation failed', errors: error_data)
    end
  end

  def test_create_business_calendar_24x7_availability_business_hours_nil
    enable_emberize_business_hours do
      params = dummy_business_calendar_default_params.merge('channel_business_hours' => dummy_channel_business_hours('ticket', '24_7_availability'))
      params['channel_business_hours'].first.merge!('business_hours' => nil)
      post :create, construct_params(params)
      error_data = [bad_request_error_pattern(:"channel_business_hours[24_7_availability]",
                                              "Parameter 'business_hours' is not allowed for 'channel_business_hours[24_7_availability]'",
                                              code: 'invalid_value')]
      assert_response 400
      match_json(description: 'Validation failed', errors: error_data)
    end
  end

  def test_create_business_calendar_24x7_availability_business_hours_empty_array
    enable_emberize_business_hours do
      params = dummy_business_calendar_default_params.merge('channel_business_hours' => dummy_channel_business_hours('ticket', '24_7_availability'))
      params['channel_business_hours'].first.merge!('business_hours' => [])
      post :create, construct_params(params)
      error_data = [bad_request_error_pattern(:"channel_business_hours[24_7_availability]",
                                              "Parameter 'business_hours' is not allowed for 'channel_business_hours[24_7_availability]'",
                                              code: 'invalid_value')]
      assert_response 400
      match_json(description: 'Validation failed', errors: error_data)
    end
  end

  def test_create_business_calendar_with_invalid_channel
    enable_emberize_business_hours do
      params = dummy_business_calendar_default_params.merge('channel_business_hours' => dummy_channel_business_hours('invalid apple'))
      params['channel_business_hours'].first.merge!('business_hours' => [])
      post :create, construct_params(params)
      error_data = [bad_request_error_pattern(:"channel_business_hours[:channel]",
                                              "It should be one of these values: 'ticket'",
                                              code: 'invalid_value')]
      assert_response 400
      match_json(description: 'Validation failed', errors: error_data)
    end
  end

  def test_create_business_calendar_with_missing_channel
    enable_emberize_business_hours do
      params = dummy_business_calendar_default_params.merge('channel_business_hours' => dummy_channel_business_hours('invalid apple'))
      params['channel_business_hours'].first.delete('channel')
      post :create, construct_params(params)
      error_data = [bad_request_error_pattern(:"channel_business_hours[:channel]",
                                              "It should be one of these values: 'ticket'",
                                              code: 'invalid_value')]
      assert_response 400
      match_json(description: 'Validation failed', errors: error_data)
    end
  end

  def test_create_business_calendar_with_nil_channel
    enable_emberize_business_hours do
      params = dummy_business_calendar_default_params.merge('channel_business_hours' => dummy_channel_business_hours(nil))
      post :create, construct_params(params)
      error_data = [bad_request_error_pattern_with_nested_field(:channel_business_hours,
                                                                'channel',
                                                                'It should be a/an String',
                                                                code: 'datatype_mismatch')]
      assert_response 400
      match_json(description: 'Validation failed', errors: error_data)
    end
  end

  def test_create_business_calendar_with_invalid_data_type_channel
    enable_emberize_business_hours do
      params = dummy_business_calendar_default_params.merge('channel_business_hours' => dummy_channel_business_hours([]))
      post :create, construct_params(params)
      error_data = [bad_request_error_pattern_with_nested_field(:channel_business_hours,
                                                                'channel',
                                                                'It should be a/an String',
                                                                code: 'datatype_mismatch')]
      assert_response 400
      match_json(description: 'Validation failed', errors: error_data)
    end
  end

  def test_create_business_calendar_with_invalid_type_business_hours
    enable_emberize_business_hours do
      params = dummy_business_calendar_default_params.merge('channel_business_hours' => dummy_channel_business_hours)
      params['channel_business_hours'].first.merge!('business_hours' => {})
      post :create, construct_params(params)
      error_data = [bad_request_error_pattern(:channel_business_hours, "'business_hours' can't be blank", code: 'invalid_value'),
                    bad_request_error_pattern(:"channel_business_hours[:business_hours]", "Expecting 'Array' but found 'INVALID'", code: 'invalid_value')]
      assert_response 400
      match_json(description: 'Validation failed', errors: error_data)
    end
  end

  def test_create_business_calendar_with_invalid_day_in_business_hours
    enable_emberize_business_hours do
      business_hours = { "business_hours": [{ "day": 'suns', "time_slots": [{ "end_time": '23:59',
                                                                              "start_time": '00:00' }] }] }
      params = dummy_business_calendar_default_params.merge('channel_business_hours' => dummy_channel_business_hours)

      params['channel_business_hours'].first.merge!(business_hours)

      post :create, construct_params(params)
      error_data = [bad_request_error_pattern(:"channel_business_hours[:business_hours][:day]",
                                              "It should be one of these values: 'sunday, monday, tuesday, wednesday, thursday, friday, saturday'",
                                              code: 'invalid_value')]
      assert_response 400
      match_json(description: 'Validation failed', errors: error_data)
    end
  end

  def test_create_business_calendar_with_empty_business_hours
    enable_emberize_business_hours do
      params = dummy_business_calendar_default_params.merge('channel_business_hours' => dummy_channel_business_hours)
      params['channel_business_hours'].first.merge!('business_hours' => [])
      post :create, construct_params(params)
      error_data = [bad_request_error_pattern(:channel_business_hours,
                                              "'business_hours' can't be blank",
                                              code: 'invalid_value')]
      assert_response 400
      match_json(description: 'Validation failed', errors: error_data)
    end
  end

  def test_create_business_calendar_with_multiple_time_slots
    enable_emberize_business_hours do
      business_hours = { "business_hours": [{ "day": 'sunday', "time_slots": [{ "end_time": '23:59',
                                                                                "start_time": '00:00' },
                                                                              { "end_time": '23:59',
                                                                                "start_time": '00:00' }] }] }
      params = dummy_business_calendar_default_params.merge('channel_business_hours' => dummy_channel_business_hours)
      params['channel_business_hours'].first.merge!(business_hours)
      post :create, construct_params(params)
      error_data = [bad_request_error_pattern(:"channel_business_hours[:business_hours][:time_slots]",
                                              "Too many time slots for 'ticket' channel in 'channel_business_hours[:business_hours][:time_slots]'",
                                              code: 'invalid_value')]
      assert_response 400
      match_json(description: 'Validation failed', errors: error_data)
    end
  end

  def test_create_business_calendar_with_missing_time_slot_keys
    enable_emberize_business_hours do
      business_hours = { "business_hours": [{ "day": 'sunday' }] }
      params = dummy_business_calendar_default_params.merge('channel_business_hours' => dummy_channel_business_hours)
      params['channel_business_hours'].first.merge!(business_hours)
      post :create, construct_params(params)
      error_data = [bad_request_error_pattern(:"channel_business_hour[:business_hours]",
                                              "It should be one of these values: 'day, time_slots'",
                                              code: 'invalid_value')]
      assert_response 400
      match_json(description: 'Validation failed', errors: error_data)
    end
  end

  def test_create_business_calendar_with_missing_start_time_or_end_time
    enable_emberize_business_hours do
      business_hours = { "business_hours": [{ "day": 'suns', "time_slots": [{ "start_time": '00:00' }] }] }
      params = dummy_business_calendar_default_params.merge('channel_business_hours' => dummy_channel_business_hours)
      params['channel_business_hours'].first.merge!(business_hours)
      post :create, construct_params(params)
      error_data = [bad_request_error_pattern(:"channel_business_hours[:business_hours][:time_slots]",
                                              "It should be one of these values: 'start_time, end_time'",
                                              code: 'invalid_value')]
      assert_response 400
      match_json(description: 'Validation failed', errors: error_data)
    end
  end

  def test_create_business_calendar_with_start_time_greater_end_time
    enable_emberize_business_hours do
      business_hours = { "business_hours": [{ "day": 'suns', "time_slots": [{ "start_time": '11:00', "end_time": '09:00' }] }] }
      params = dummy_business_calendar_default_params.merge('channel_business_hours' => dummy_channel_business_hours)
      params['channel_business_hours'].first.merge!(business_hours)
      post :create, construct_params(params)
      error_data = [bad_request_error_pattern(:"channel_business_hours[:business_hours][:time_slots][:start_time/end_time]",
                                              'Please enter a valid time slot',
                                              code: 'invalid_value')]
      assert_response 400
      match_json(description: 'Validation failed', errors: error_data)
    end
  end

  def test_create_business_calendar_with_start_time_equal_end_time
    enable_emberize_business_hours do
      business_hours = { "business_hours": [{ "day": 'suns', "time_slots": [{ "start_time": '11:00', "end_time": '11:00' }] }] }
      params = dummy_business_calendar_default_params.merge('channel_business_hours' => dummy_channel_business_hours)
      params['channel_business_hours'].first.merge!(business_hours)
      post :create, construct_params(params)
      error_data = [bad_request_error_pattern(:"channel_business_hours[:business_hours][:time_slots][:start_time/end_time]",
                                              'Please enter a valid time slot',
                                              code: 'invalid_value')]
      assert_response 400
      match_json(description: 'Validation failed', errors: error_data)
    end
  end

  def test_create_business_calendar_with_wrong_minute_in_time_slot
    enable_emberize_business_hours do
      business_hours = { "business_hours": [{ "day": 'sunday', "time_slots": [{ "start_time": '11:59', "end_time": '12:30' }] }] }
      params = dummy_business_calendar_default_params.merge('channel_business_hours' => dummy_channel_business_hours).merge(dummy_holiday_data)
      params['channel_business_hours'].first.merge!(business_hours)
      post :create, construct_params(params)
      assert_response 201
      created_business_calendar = Account.current.business_calendar.where(name: 'Dark web with social engineering').first
      match_json(ember_business_hours_create_pattern(created_business_calendar, params.with_indifferent_access))
    end
  end

  def test_create_business_calendar_with_valid_minute_in_time_slot
    enable_emberize_business_hours do
      business_hours = { "business_hours": [{ "day": 'sunday', "time_slots": [{ "start_time": '11:08', "end_time": '12:30' }] }] }
      params = dummy_business_calendar_default_params.merge('channel_business_hours' => dummy_channel_business_hours).merge(dummy_holiday_data)
      params['channel_business_hours'].first.merge!(business_hours)
      post :create, construct_params(params)

      assert_response 201
      created_business_calendar = Account.current.business_calendar.where(name: 'Dark web with social engineering').first
      match_json(ember_business_hours_create_pattern(created_business_calendar, params.with_indifferent_access))
    end
  end

  def test_create_business_calendar_with_invalid_time_in_time_slot
    enable_emberize_business_hours do
      business_hours = { "business_hours": [{ "day": 'sunday', "time_slots": [{ "start_time": '11:80', "end_time": '12:30' }] }] }
      params = dummy_business_calendar_default_params.merge('channel_business_hours' => dummy_channel_business_hours)
      params['channel_business_hours'].first.merge!(business_hours)
      post :create, construct_params(params)
      error_data = [bad_request_error_pattern(:"channel_business_hours[:business_hours][:time_slots][:start_time/end_time]",
                                              "HH should be between 0 and 23 inclusive and MM should be inside the range inclusive of '00..59'",
                                              code: 'invalid_value')]
      assert_response 400
      match_json(description: 'Validation failed', errors: error_data)
    end
  end

  def test_create_business_calendar_with_duplicate_holiday_date
    enable_emberize_business_hours do
      params = dummy_business_calendar_default_params.merge('channel_business_hours' => dummy_channel_business_hours('ticket', '24_7_availability'))
                                                     .merge('holidays' => [{ "date": 'Feb 18', "name": 'feb 18 holiday' }, { "date": 'Feb 18', "name": 'feb 18 holiday' }])
      post :create, construct_params(params)
      error_data = [bad_request_error_pattern(:holidays,
                                              'Duplicate holiday date is present',
                                              code: 'invalid_value')]
      assert_response 400
      match_json(description: 'Validation failed', errors: error_data)
    end
  end

  def test_create_business_calendar_with_duplicate_business_hours_day
    enable_emberize_business_hours do
      business_hours = { "business_hours": [{ "day": 'sunday', "time_slots": [{ "end_time": '23:59',
                                                                                "start_time": '00:00' }] },
                                            { "day": 'sunday', "time_slots": [{ "end_time": '10:00',
                                                                                "start_time": '00:00' }] }] }
      params = dummy_business_calendar_default_params.merge('channel_business_hours' => dummy_channel_business_hours)
      params['channel_business_hours'].first.merge!(business_hours)
      post :create, construct_params(params)
      error_data = [bad_request_error_pattern(:"channel_business_hours['business_hours']",
                                              'Duplicate business day is present',
                                              code: 'invalid_value')]
      assert_response 400
      match_json(description: 'Validation failed', errors: error_data)
    end
  end

  private

    def enable_emberize_business_hours
      Account.current.launch :emberize_business_hours
      yield
    ensure
      Account.current.rollback :emberize_business_hours
    end
end
