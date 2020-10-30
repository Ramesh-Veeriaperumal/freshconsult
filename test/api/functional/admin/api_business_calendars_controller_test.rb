require_relative '../../test_helper.rb'
require 'webmock/minitest'
require 'sidekiq/testing'
%w[business_calendars_helper.rb].each { |file| require "#{Rails.root}/test/core/helpers/#{file}" }
require Rails.root.join('test', 'api', 'helpers', 'admin', 'api_business_calendar_helper.rb')
require Rails.root.join('test', 'models', 'helpers', 'freshchat_account_test_helper.rb')
WebMock.allow_net_connect!

class Admin::ApiBusinessCalendarsControllerTest < ActionController::TestCase
  include BusinessHoursTestHelper
  include Admin::ApiBusinessCalendarHelper
  include ::Freshcaller::TestHelper
  include FreshchatAccountTestHelper
  include BusinessCalendarsTestHelper
  include Helpdesk::IrisNotifications

  def setup
    super
    Sidekiq::Worker.clear_all
    Account.stubs(:current).returns(Account.last)
    User.stubs(:current).returns(User.first)
    Account.any_instance.stubs(:multiple_business_hours_enabled?).returns(true)
    @account = Account.current
    WebMock.enable!
  end

  def teardown
    Account.current.business_calendar.where(name: 'Dark web with social engineering').each(&:destroy)
    Account.unstub(:current)
    User.unstub(:current)
    Account.any_instance.unstub(:multiple_business_hours_enabled?)
    Admin::BusinessCalendar::OmniSyncWorker.clear
    WebMock.reset!
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

  def test_check_queue_size_when_destroying_omni_business_calendar
    enable_emberize_business_hours do
      enable_omni_business_hours do
        Sidekiq::Testing.fake! do
          business_calendar = create_business_calendar
          Admin::BusinessCalendar::OmniSyncWorker.clear
          delete :destroy, construct_params(id: business_calendar.id)
          assert_response 204
          assert_equal Admin::BusinessCalendar::OmniSyncWorker.jobs.size, 2
        end
      end
    end
  end

  def test_destroy_omni_business_calendar_freshcaller_success
    enable_omni_business_calendar_destroy do
      business_calendar = create_business_calendar
      calendar_id = business_calendar.id
      Admin::BusinessCalendar::OmniSyncWorker.clear
      stub_business_calendar_delete_success(calendar_id)
      delete :destroy, construct_params(id: calendar_id)
      assert_response 204
      Admin::BusinessCalendar::OmniSyncWorker.drain
      assert_requested(:delete, business_calendar_show_url(calendar_id), times: 1)
    end
  end

  def test_destroy_omni_business_calendar_freshcaller_unauthorized
    enable_omni_business_calendar_destroy do
      business_calendar = create_business_calendar
      calendar_id = business_calendar.id
      Admin::BusinessCalendar::OmniSyncWorker.clear
      stub_business_calendar_delete_unauthorized(calendar_id)
      delete :destroy, construct_params(id: calendar_id)
      assert_response 204
      Admin::BusinessCalendar::OmniSyncWorker.drain
      assert_requested(:delete, business_calendar_show_url(calendar_id), times: 1)
    end
  end

  def test_destroy_omni_business_calendar_freshcaller_invalid_authorization
    enable_omni_business_calendar_destroy do
      business_calendar = create_business_calendar
      calendar_id = business_calendar.id
      Admin::BusinessCalendar::OmniSyncWorker.clear
      stub_business_calendar_delete_invalid_authentication(calendar_id)
      delete :destroy, construct_params(id: calendar_id)
      assert_response 204
      Admin::BusinessCalendar::OmniSyncWorker.drain
      assert_requested(:delete, business_calendar_show_url(calendar_id), times: 1)
    end
  end

  def test_destroy_omni_business_calendar_freshcaller_not_found
    enable_omni_business_calendar_destroy do
      business_calendar = create_business_calendar
      calendar_id = business_calendar.id
      Admin::BusinessCalendar::OmniSyncWorker.clear
      stub_business_calendar_delete_not_found(calendar_id)
      delete :destroy, construct_params(id: calendar_id)
      assert_response 204
      Admin::BusinessCalendar::OmniSyncWorker.drain
      assert_requested(:delete, business_calendar_show_url(calendar_id), times: 1)
    end
  end

  def test_destroy_omni_business_calendar_freshchat_success
    enable_omni_business_calendar_destroy do
      business_calendar = create_business_calendar
      calendar_id = business_calendar.id
      #business_calendar.update_sync_status_without_callbacks(ApiBusinessCalendarConstants::FRESHCALLER_PRODUCT, 'delete', OMNI_SYNC_STATUS[:inprogress])
      Admin::BusinessCalendar::OmniSyncWorker.clear
      stub_business_calendar_delete_success(calendar_id)
      delete_url = "https://api.freshchat.com/v2/business_hours/#{calendar_id}"
      response_hash = {
        code: 204,
        message: 'Delete request accepted'
      }
      stub_request(:delete, delete_url).to_return(body: response_hash.to_json, status: 204)
      delete :destroy, construct_params(id: calendar_id)
      assert_response 204
      Admin::BusinessCalendar::OmniSyncWorker.drain
      assert_requested(:delete, delete_url, times: 1)
    end
  end

  def test_destroy_omni_business_calendar_freshchat_failure
    enable_omni_business_calendar_destroy do
      business_calendar = create_business_calendar
      Admin::BusinessCalendar::OmniSyncWorker.clear
      calendar_id = business_calendar.id
      stub_business_calendar_delete_success(calendar_id)
      delete_url = "https://api.freshchat.com/v2/business_hours/#{calendar_id}"
      stub_request(:delete, delete_url).to_return(body: {}.to_json, status: 404)
      delete :destroy, construct_params(id: calendar_id)
      assert_response 204
      Admin::BusinessCalendar::OmniSyncWorker.drain
      assert_requested(:delete, delete_url, times: 1)
    end
  end

  def test_show_omni_business_calendar_success
    enable_emberize_business_hours do
      business_calendar = create_business_calendar
      calendar_id = business_calendar.id
      enable_omni_business_hours do
        business_calendar.set_sync_channel_status(ApiBusinessCalendarConstants::FRESHCALLER_PRODUCT, 'create', BusinessCalenderConstants::OMNI_SYNC_STATUS[:success])
        business_calendar.set_sync_channel_status(ApiBusinessCalendarConstants::FRESHCHAT_PRODUCT, 'create', BusinessCalenderConstants::OMNI_SYNC_STATUS[:success])
        business_calendar.save
        freshchat_get_url = format('%{url}/%{id}', url: chat_create_url, id: calendar_id)
        stub_request(:get, freshchat_get_url).to_return(body: show_chat_business_hours_sample(calendar_id).to_json, status: 200)
        stub_show_business_calendar_success(calendar_id)
        get :show, controller_params(id: business_calendar.id)
        response = JSON.parse(@response.body)
        channel_hours = response['channel_business_hours']
        assert_response 200
        assert_requested(:get, freshchat_get_url, times: 1)
        assert_requested(:get, business_calendar_show_url(calendar_id), times: 1)
        assert_equal channel_hours.size, 3
        expected_channel_hours = [
            business_calendar.freshdesk_business_hour_data,
            chat_channel_business_hours_sample[:channel_business_hours][0].merge({'sync_status' => BusinessCalenderConstants::OMNI_SYNC_STATUS[:success]}),
            caller_channel_business_hours_sample[:channel_business_hours][0].merge({'sync_status' => BusinessCalenderConstants::OMNI_SYNC_STATUS[:success]})
        ]
        match_json(omni_business_hours_show_pattern(business_calendar, expected_channel_hours))
        Account.any_instance.stubs(:omni_business_calendar?).returns(false)
        business_calendar.destroy
      end
    end
  end

  # create is successful, update is done but not yet synced. Now get api response test.
  def test_show_omni_business_calendar_success_with_sync_status_inprogress
    enable_emberize_business_hours do
      business_calendar = create_business_calendar
      calendar_id = business_calendar.id
      enable_omni_business_hours_with_sidekiq_fake do
        business_calendar.reload
        business_calendar.set_sync_channel_status(ApiBusinessCalendarConstants::FRESHCALLER_PRODUCT, 'create', BusinessCalenderConstants::OMNI_SYNC_STATUS[:inprogress])
        business_calendar.set_sync_channel_status(ApiBusinessCalendarConstants::FRESHCHAT_PRODUCT, 'create', BusinessCalenderConstants::OMNI_SYNC_STATUS[:failed])
        business_calendar.save
        freshchat_get_url = format('%{url}/%{id}', url: chat_create_url, id: calendar_id)
        stub_request(:get, freshchat_get_url).to_return(body: show_chat_business_hours_sample(calendar_id).to_json, status: 200)
        stub_show_business_calendar_success(calendar_id)
        get :show, controller_params(id: business_calendar.id)
        response = JSON.parse(@response.body)
        channel_hours = response['channel_business_hours']
        assert_response 200
        assert_requested(:get, freshchat_get_url, times: 1)
        assert_requested(:get, business_calendar_show_url(calendar_id), times: 1)
        assert_equal channel_hours.size, 3
        expected_channel_hours = [
            business_calendar.freshdesk_business_hour_data,
            chat_channel_business_hours_sample[:channel_business_hours][0].merge({'sync_status' => BusinessCalenderConstants::OMNI_SYNC_STATUS[:failed]}),
            caller_channel_business_hours_sample[:channel_business_hours][0].merge({'sync_status' => BusinessCalenderConstants::OMNI_SYNC_STATUS[:inprogress]})
        ]
        match_json(omni_business_hours_show_pattern(business_calendar, expected_channel_hours))
        Account.any_instance.stubs(:omni_business_calendar?).returns(false)
        business_calendar.destroy
      end
    end
  end

  def test_show_omni_business_calendar_freshcaller_failure
    enable_emberize_business_hours do
      business_calendar = create_business_calendar
      calendar_id = business_calendar.id
      enable_omni_business_hours do
        freshchat_get_url = format('%{url}/%{id}', url: chat_create_url, id: calendar_id)
        stub_request(:get, freshchat_get_url).to_return(body: show_chat_business_hours_sample(calendar_id).to_json, status: 200)
        stub_show_business_calendar_failure(calendar_id)
        get :show, controller_params(id: business_calendar.id)
        response = JSON.parse(@response.body)
        assert_response 503
        assert_equal response['message'], 'Omni Business Calendar GET request failed'
        Account.any_instance.stubs(:omni_business_calendar?).returns(false)
        business_calendar.destroy
      end
    end
  end

  def test_show_omni_business_calendar_freshchat_failure
    enable_emberize_business_hours do
      business_calendar = create_business_calendar
      calendar_id = business_calendar.id
      enable_omni_business_hours_with_sidekiq_fake do
        freshchat_get_url = format('%{url}/%{id}', url: chat_create_url, id: calendar_id)
        stub_request(:get, freshchat_get_url).to_return(body: {}.to_json, status: 503)
        stub_show_business_calendar_success(calendar_id)
        get :show, controller_params(id: business_calendar.id)
        response = JSON.parse(@response.body)
        assert_response 503
        assert_equal response['message'], 'Omni Business Calendar GET request failed'
        Account.any_instance.stubs(:omni_business_calendar?).returns(false)
        business_calendar.destroy
      end
    end
  end

  def test_show_omni_business_calendar_freshcaller_failure_404
    enable_emberize_business_hours do
      business_calendar = create_business_calendar
      calendar_id = business_calendar.id
      enable_omni_business_hours do
        business_calendar.set_sync_channel_status(ApiBusinessCalendarConstants::FRESHCALLER_PRODUCT, 'create', BusinessCalenderConstants::OMNI_SYNC_STATUS[:failed])
        business_calendar.set_sync_channel_status(ApiBusinessCalendarConstants::FRESHCHAT_PRODUCT, 'create', BusinessCalenderConstants::OMNI_SYNC_STATUS[:success])
        business_calendar.save
        freshchat_get_url = format('%{url}/%{id}', url: chat_create_url, id: calendar_id)
        stub_request(:get, freshchat_get_url).to_return(body: show_chat_business_hours_sample(calendar_id).to_json, status: 200)
        stub_freshcaller_show_bc_failure(calendar_id)
        get :show, controller_params(id: business_calendar.id)
        response = JSON.parse(@response.body)
        assert_response 200
        expected_channel_hours = [
            business_calendar.freshdesk_business_hour_data,
            chat_channel_business_hours_sample[:channel_business_hours][0].merge({'sync_status' => BusinessCalenderConstants::OMNI_SYNC_STATUS[:success]}),
            {'channel': 'phone' }.merge({'sync_status' => BusinessCalenderConstants::OMNI_SYNC_STATUS[:failed]})
        ]
        match_json(omni_business_hours_show_pattern(business_calendar, expected_channel_hours))
        Account.any_instance.stubs(:omni_business_calendar?).returns(false)
        business_calendar.destroy
      end
    end
  ensure
    WebMock.reset!
  end

  def test_show_omni_business_calendar_freshchat_failure_404
    enable_emberize_business_hours do
      business_calendar = create_business_calendar
      calendar_id = business_calendar.id
      enable_omni_business_hours do
        business_calendar.set_sync_channel_status(ApiBusinessCalendarConstants::FRESHCALLER_PRODUCT, 'create', BusinessCalenderConstants::OMNI_SYNC_STATUS[:success])
        business_calendar.set_sync_channel_status(ApiBusinessCalendarConstants::FRESHCHAT_PRODUCT, 'create', BusinessCalenderConstants::OMNI_SYNC_STATUS[:failed])
        business_calendar.save
        freshchat_get_url = format('%{url}/%{id}', url: chat_create_url, id: calendar_id)
        stub_request(:get, freshchat_get_url).to_return(body: {}.to_json, status: 404)
        stub_show_business_calendar_success(calendar_id)
        get :show, controller_params(id: business_calendar.id)
        response = JSON.parse(@response.body)
        assert_response 200
        expected_channel_hours = [
            business_calendar.freshdesk_business_hour_data,
            {'channel': 'chat' }.merge({'sync_status' => BusinessCalenderConstants::OMNI_SYNC_STATUS[:failed]}),
            caller_channel_business_hours_sample[:channel_business_hours][0].merge({'sync_status' => BusinessCalenderConstants::OMNI_SYNC_STATUS[:success]})
        ]
        match_json(omni_business_hours_show_pattern(business_calendar, expected_channel_hours))
        Account.any_instance.stubs(:omni_business_calendar?).returns(false)
        business_calendar.destroy
      end
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
      post :create, construct_params(params)
      error_data = [bad_request_error_pattern(:"channel_business_hours",
                                              "Expected 1 channel, 'ticket'",
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
      error_data = [bad_request_error_pattern(:"channel_business_hours",
                                              "Expected 1 channel, 'ticket'",
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
      business_hours = { "business_hours": [{ "day": 'sunday', "time_slots": [{ "end_time": '10:00',
                                                                                "start_time": '00:00' },
                                                                              { "end_time": '23:59',
                                                                                "start_time": '10:30' }] }] }
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

  def test_create_bc_for_omni_with_invalid_breaks
    enable_emberize_business_hours do
      enable_omni_business_hours do
        params = dummy_business_calendar_default_params.merge(
            'channel_business_hours' => [
                ticket_business_hours_sample,
                caller_channel_business_hours_sample[:channel_business_hours][0],
                chat_channel_business_hours_sample[:channel_business_hours][0].merge(
                    "business_hours": [{ "day": 'sunday', "time_slots": [{ "end_time": '11:30',
                                                                           "start_time": '10:00' },
                                                                         { "end_time": '10:30',
                                                                           "start_time": '00:00' },
                                                                         { "end_time": '16:00',
                                                                           "start_time": '14:00' }] },
                                       { "day": 'monday', "time_slots": [{ "end_time": '10:00',
                                                                           "start_time": '00:00' }] }]
                )
            ]
        ).merge(dummy_holiday_data)
        post :create, construct_params(params)
        error_data = [bad_request_error_pattern(:"channel_business_hours[:business_hours][:time_slots]",
                                                'Please enter valid time slots with breaks in between the slots',
                                                code: 'invalid_value')]
        assert_response 400
        match_json(description: 'Validation failed', errors: error_data)
      end
    end
  end

  def test_create_bc_for_omni_with_away_message_for_ticket
    enable_emberize_business_hours do
      enable_omni_business_hours do
        params = dummy_business_calendar_default_params.merge(
            'channel_business_hours' => [
                ticket_business_hours_sample.merge({
                                                       "away_message": 'I am away'
                                                   }),
                caller_channel_business_hours_sample[:channel_business_hours][0],
                chat_channel_business_hours_sample[:channel_business_hours][0]
            ]
        ).merge(dummy_holiday_data)
        post :create, construct_params(params)
        error_data = [bad_request_error_pattern('away_message',
                                                'Unexpected/invalid field in request',
                                                code: 'invalid_field')]
        assert_response 400
        match_json(description: 'Validation failed', errors: error_data)
      end
    end
  end

  def test_create_bc_for_omni_with_away_message_for_phone
    enable_emberize_business_hours do
      enable_omni_business_hours do
        params = dummy_business_calendar_default_params.merge(
            'channel_business_hours' => [
                ticket_business_hours_sample,
                caller_channel_business_hours_sample[:channel_business_hours][0].merge({
                                                                                           "away_message": 'I am away'
                                                                                       }),
                chat_channel_business_hours_sample[:channel_business_hours][0]
            ]
        ).merge(dummy_holiday_data)
        post :create, construct_params(params)
        error_data = [bad_request_error_pattern('away_message',
                                                'Unexpected/invalid field in request',
                                                code: 'invalid_field')]
        assert_response 400
        match_json(description: 'Validation failed', errors: error_data)
      end
    end
  end

  def test_create_bc_for_omni_with_away_message_for_chat
    enable_emberize_business_hours do
      enable_omni_business_hours_with_sidekiq_fake do
        stub_omni_success(chat: chat_channel_business_hours_away_message_sample) do
          params = dummy_business_calendar_default_params.merge(
            'channel_business_hours' => [
              ticket_business_hours_sample,
              chat_channel_business_hours_away_message_sample[:channel_business_hours][0],
              caller_channel_business_hours_sample[:channel_business_hours][0]
            ]
          ).merge(dummy_holiday_data)
          post :create, construct_params(params)
          assert_response 202
          created_business_calendar = Account.current.business_calendar.where(name: 'Dark web with social engineering').first
          match_json(ember_business_hours_create_pattern(created_business_calendar, expected_create_response(params).with_indifferent_access))
          assert_equal BusinessCalenderConstants::OMNI_SYNC_STATUS[:inprogress], created_business_calendar.sync_freshcaller_status
          assert_equal BusinessCalenderConstants::OMNI_SYNC_STATUS[:inprogress], created_business_calendar.sync_freshchat_status
        end
      end
    end
  end

  def test_create_bc_for_omni_with_breaks
    enable_emberize_business_hours do
      enable_omni_business_hours_with_sidekiq_fake do
        stub_omni_success(chat: chat_channel_business_hours_breaks_sample) do
          params = dummy_business_calendar_default_params.merge(
            'channel_business_hours' => [
              ticket_business_hours_sample,
              chat_channel_business_hours_breaks_sample[:channel_business_hours][0],
              caller_channel_business_hours_sample[:channel_business_hours][0]
            ]
          ).merge(dummy_holiday_data)
          post :create, construct_params(params)
          assert_response 202
          created_business_calendar = Account.current.business_calendar.where(name: 'Dark web with social engineering').first
          match_json(ember_business_hours_create_pattern(created_business_calendar, expected_create_response(params).with_indifferent_access))
          assert_equal BusinessCalenderConstants::OMNI_SYNC_STATUS[:inprogress], created_business_calendar.sync_freshcaller_status
          assert_equal BusinessCalenderConstants::OMNI_SYNC_STATUS[:inprogress], created_business_calendar.sync_freshchat_status
        end
      end
    end
  end

  def test_create_bc_freshcaller_success
    enable_emberize_business_hours do
      enable_omni_business_hours_with_sidekiq_fake do
        stub_omni_success(chat: chat_channel_business_hours_sample, phone: caller_channel_business_hours_sample) do
          params = dummy_business_calendar_default_params.merge(
            'channel_business_hours' => [
              ticket_business_hours_sample,
              caller_channel_business_hours_sample[:channel_business_hours][0],
              chat_channel_business_hours_sample[:channel_business_hours][0]
            ]
          ).merge(dummy_holiday_data)
          post :create, construct_params(params)
          assert_response 202
          created_business_calendar = Account.current.business_calendar.where(name: 'Dark web with social engineering').first
          match_json(ember_business_hours_create_pattern(created_business_calendar, expected_create_response(params).with_indifferent_access))
          assert_equal BusinessCalenderConstants::OMNI_SYNC_STATUS[:inprogress], created_business_calendar.sync_freshcaller_status
          assert_equal BusinessCalenderConstants::OMNI_SYNC_STATUS[:inprogress], created_business_calendar.sync_freshchat_status
        end
      end
    end
  end

  def test_create_bc_freshcaller_success_with_background_proccessing
    enable_emberize_business_hours do
      enable_omni_business_hours_with_sidekiq_fake do
        stub_omni_success(chat: chat_channel_business_hours_sample, phone: caller_channel_business_hours_sample) do
          params = dummy_business_calendar_default_params.merge(
              'channel_business_hours' => [
                  ticket_business_hours_sample,
                  caller_channel_business_hours_sample[:channel_business_hours][0],
                  chat_channel_business_hours_sample[:channel_business_hours][0]
              ]
          ).merge(dummy_holiday_data)
          post :create, construct_params(params)
          assert_response 202
          Admin::BusinessCalendar::OmniSyncWorker.drain
          assert_requested(:post, business_calendar_create_url, times: 1)
          assert_requested(:post, chat_create_url, times: 1)
          created_business_calendar = Account.current.business_calendar.where(name: 'Dark web with social engineering').first
          assert_equal BusinessCalenderConstants::OMNI_SYNC_STATUS[:success], created_business_calendar.sync_freshcaller_status
          assert_equal BusinessCalenderConstants::OMNI_SYNC_STATUS[:success], created_business_calendar.sync_freshchat_status
        end
      end
    end
  end
  #
  def test_create_bc_freshcaller_failure
    enable_emberize_business_hours do
      enable_omni_business_hours_with_sidekiq_fake do
        stub_bc_create_failure
        stub_chat_bc_success(chat: chat_channel_business_hours_sample)
        params = dummy_business_calendar_default_params.merge(
            'channel_business_hours' => [
                ticket_business_hours_sample,
                caller_channel_business_hours_sample[:channel_business_hours][0],
                chat_channel_business_hours_sample[:channel_business_hours][0]
            ]
        ).merge(dummy_holiday_data)
        post :create, construct_params(params)
        assert_response 202
        created_business_calendar = Account.current.business_calendar.where(name: 'Dark web with social engineering').first
        match_json(ember_business_hours_create_pattern(created_business_calendar, expected_create_response(params).with_indifferent_access))
        Admin::BusinessCalendar::OmniSyncWorker.drain
        assert_requested(:post, business_calendar_create_url, times: 1)
        assert_requested(:post, chat_create_url, times: 1)
        created_business_calendar.reload
        assert_equal BusinessCalenderConstants::OMNI_SYNC_STATUS[:failed], created_business_calendar.sync_freshcaller_status
        assert_equal BusinessCalenderConstants::OMNI_SYNC_STATUS[:success], created_business_calendar.sync_freshchat_status
      end
    end
  ensure
    WebMock.reset!
  end

  def test_create_bc_freshchat_failure
    enable_emberize_business_hours do
      enable_omni_business_hours_with_sidekiq_fake do
        stub_caller_bc_create_success(phone: caller_channel_business_hours_sample)
        stub_chat_create_failure
        params = dummy_business_calendar_default_params.merge(
            'channel_business_hours' => [
                ticket_business_hours_sample,
                caller_channel_business_hours_sample[:channel_business_hours][0],
                chat_channel_business_hours_sample[:channel_business_hours][0]
            ]
        )
        post :create, construct_params(params)
        assert_response 202
        created_business_calendar = Account.current.business_calendar.where(name: 'Dark web with social engineering').first
        match_json(ember_business_hours_create_pattern(created_business_calendar, expected_create_response(params).with_indifferent_access))
        Admin::BusinessCalendar::OmniSyncWorker.drain
        assert_requested(:post, business_calendar_create_url, times: 1)
        assert_requested(:post, chat_create_url, times: 1)
        created_business_calendar.reload
        assert_equal BusinessCalenderConstants::OMNI_SYNC_STATUS[:success], created_business_calendar.sync_freshcaller_status
        assert_equal BusinessCalenderConstants::OMNI_SYNC_STATUS[:failed], created_business_calendar.sync_freshchat_status
      end
    end
  ensure
    WebMock.reset!
  end

  def test_coverage_for_logs_in_exception
    enable_emberize_business_hours do
      enable_omni_business_hours_with_sidekiq_fake do
        Omni::BusinessCalendarSync.any_instance.expects(:send_channel_request).raises('some custom error')
        Omni::FreshcallerBcSync.any_instance.expects(:send_channel_request).raises('some custom error')
        params = dummy_business_calendar_default_params.merge(
            'channel_business_hours' => [
                ticket_business_hours_sample,
                caller_channel_business_hours_sample[:channel_business_hours][0],
                chat_channel_business_hours_sample[:channel_business_hours][0]
            ])
        post :create, construct_params(params)
        assert_response 202
        created_business_calendar = Account.current.business_calendar.where(name: 'Dark web with social engineering').first
        assert_equal BusinessCalenderConstants::OMNI_SYNC_STATUS[:inprogress], created_business_calendar.sync_freshcaller_status
        assert_equal BusinessCalenderConstants::OMNI_SYNC_STATUS[:inprogress], created_business_calendar.sync_freshchat_status
      end
    end
  ensure
    Omni::BusinessCalendarSync.any_instance.unstub(:send_channel_request)
    Omni::FreshcallerBcSync.any_instance.unstub(:send_channel_request)
  end

  def test_create_with_invalid_number_of_channels
    enable_emberize_business_hours do
      params = dummy_business_calendar_default_params.merge('channel_business_hours' => dummy_channel_business_hours)
      params = dummy_business_calendar_default_params.merge(
          'channel_business_hours' => [
              ticket_business_hours_sample,
              caller_channel_business_hours_sample[:channel_business_hours][0],
              chat_channel_business_hours_sample[:channel_business_hours][0]
          ]
      ).merge(dummy_holiday_data)
      post :create, construct_params(params)
      error_data = [bad_request_error_pattern(:"channel_business_hours",
                                              "Expected 1 channel, '#{ApiBusinessCalendarConstants::TICKET_CHANNEL}'",
                                              code: 'invalid_value')]
      assert_response 400
      match_json(description: 'Validation failed', errors: error_data)
    end
  end

  def test_create_with_invalid_number_of_channels_for_omni
    enable_emberize_business_hours do
      enable_omni_business_hours_with_sidekiq_fake do
        params = dummy_business_calendar_default_params.merge('channel_business_hours' => dummy_channel_business_hours)
        params = dummy_business_calendar_default_params.merge(
            'channel_business_hours' => [
                ticket_business_hours_sample,
                caller_channel_business_hours_sample[:channel_business_hours][0],
                chat_channel_business_hours_sample[:channel_business_hours][0],
                ticket_business_hours_sample
            ]
        ).merge(dummy_holiday_data)
        post :create, construct_params(params)
        error_data = [bad_request_error_pattern(:"channel_business_hours",
                                                "Expected 3 channel, '#{[ApiBusinessCalendarConstants::TICKET_CHANNEL, ApiBusinessCalendarConstants::CHAT_CHANNEL, ApiBusinessCalendarConstants::PHONE_CHANNEL].join(',')}'",
                                                code: 'invalid_value')]
        assert_response 400
        match_json(description: 'Validation failed', errors: error_data)
      end
    end
  end

  def test_create_with_valid_number_of_channels_for_omni
    enable_emberize_business_hours do
      enable_omni_business_hours_with_sidekiq_fake do
        params = dummy_business_calendar_default_params.merge(
            'channel_business_hours' => [
                ticket_business_hours_sample,
                caller_channel_business_hours_sample[:channel_business_hours][0],
                chat_channel_business_hours_sample[:channel_business_hours][0]
            ]
        ).merge(dummy_holiday_data)
        post :create, construct_params(params)
        assert_response 202
      end
    end
  end

  def test_update_business_calendar_for_omni_with_invalid_breaks
    enable_emberize_business_hours do
      enable_omni_business_hours do
        business_hours = {
            "channel": 'chat',
            "business_hours_type": 'custom',
            "business_hours": [{ "day": 'sunday', "time_slots": [{ "end_time": '11:30',
                                                                   "start_time": '10:00' },
                                                                 { "end_time": '10:30',
                                                                   "start_time": '00:00' },
                                                                 { "end_time": '16:00',
                                                                   "start_time": '14:00' }] },
                               { "day": 'monday', "time_slots": [{ "end_time": '10:00',
                                                                   "start_time": '00:00' }] }]
        }
        params = {
            'channel_business_hours' => [
                ticket_business_hours_sample,
                caller_channel_business_hours_sample[:channel_business_hours][0],
                business_hours,
            ]
        }
        business_calendar = create_business_calendar(name: 'Dark web with social engineering')
        put :update, construct_params({ id: business_calendar.id }, params)
        error_data = [bad_request_error_pattern(:"channel_business_hours[:business_hours][:time_slots]",
                                                'Please enter valid time slots with breaks in between the slots',
                                                code: 'invalid_value')]
        assert_response 400
        match_json(description: 'Validation failed', errors: error_data)
      end
    end
  end

  def test_update_business_calendar_for_omni_with_away_message_for_ticket
    enable_emberize_business_hours do
      enable_omni_business_hours do
        params = {
            'channel_business_hours' => [
                ticket_business_hours_sample.merge(
                    "away_message": 'Gone!'
                ),
                caller_channel_business_hours_sample[:channel_business_hours][0],
                chat_channel_business_hours_sample[:channel_business_hours][0],
            ]
        }
        business_calendar = create_business_calendar(name: 'Dark web with social engineering')
        put :update, construct_params({ id: business_calendar.id }, params)
        error_data = [bad_request_error_pattern('away_message',
                                                'Unexpected/invalid field in request',
                                                code: 'invalid_field')]
        assert_response 400
        match_json(description: 'Validation failed', errors: error_data)
      end
    end
  end

  def test_update_business_calendar_for_omni_with_away_message_for_phone
    enable_emberize_business_hours do
      enable_omni_business_hours do
        params = {
            'channel_business_hours' => [
                ticket_business_hours_sample,
                caller_channel_business_hours_sample[:channel_business_hours][0].merge(
                    "away_message": 'Gone!'
                ),
                chat_channel_business_hours_sample[:channel_business_hours][0],
            ]
        }
        business_calendar = create_business_calendar(name: 'Dark web with social engineering')
        put :update, construct_params({ id: business_calendar.id }, params)
        error_data = [bad_request_error_pattern('away_message',
                                                'Unexpected/invalid field in request',
                                                code: 'invalid_field')]
        assert_response 400
        match_json(description: 'Validation failed', errors: error_data)
      end
    end
  end

  def test_update_business_calendar_for_omni_with_away_message_for_chat
    enable_emberize_business_hours do
      enable_omni_business_hours_with_sidekiq_fake do
        business_calendar = create_business_calendar(name: 'Dark web with social engineering')
        stub_omni_update_success(business_calendar.id, { chat: chat_channel_business_hours_away_message_sample }) do
          params = { 'channel_business_hours' => [
              ticket_business_hours_sample,
              caller_channel_business_hours_sample[:channel_business_hours][0],
              chat_channel_business_hours_away_message_sample[:channel_business_hours][0]
          ] }
          put :update, construct_params({ id: business_calendar.id }, params)
          assert_response 202
          updated_business_calendar = Account.current.business_calendar.where(name: 'Dark web with social engineering').first
          match_json(ember_business_hours_create_pattern(updated_business_calendar, expected_create_response(params).with_indifferent_access))
          assert_equal BusinessCalenderConstants::OMNI_SYNC_STATUS[:inprogress], updated_business_calendar.sync_freshcaller_status
          assert_equal BusinessCalenderConstants::OMNI_SYNC_STATUS[:inprogress], updated_business_calendar.sync_freshchat_status
        end
      end
    end
  end

  def test_update_business_calendar_for_omni_with_breaks
    enable_emberize_business_hours do
      enable_omni_business_hours_with_sidekiq_fake do
        business_calendar = create_business_calendar(name: 'Dark web with social engineering')
        stub_omni_update_success(business_calendar.id, { chat: chat_channel_business_hours_breaks_sample }) do
          params = { 'channel_business_hours' => [
              ticket_business_hours_sample,
              chat_channel_business_hours_breaks_sample[:channel_business_hours][0],
              caller_channel_business_hours_sample[:channel_business_hours][0]
          ] }
          put :update, construct_params({ id: business_calendar.id }, params)
          assert_response 202
          updated_business_calendar = Account.current.business_calendar.where(name: 'Dark web with social engineering').first
          match_json(ember_business_hours_create_pattern(updated_business_calendar, expected_create_response(params).merge(holidays: business_calendar.holiday_data.map { |data| { name: data[1], date: data[0] } }).with_indifferent_access))
          assert_equal BusinessCalenderConstants::OMNI_SYNC_STATUS[:inprogress], updated_business_calendar.sync_freshcaller_status
          assert_equal BusinessCalenderConstants::OMNI_SYNC_STATUS[:inprogress], updated_business_calendar.sync_freshchat_status
        end
      end
    end
  end

  def test_update_business_calendar_success
    enable_emberize_business_hours do
      enable_omni_business_hours_with_sidekiq_fake do
        business_calendar = create_business_calendar(name: 'Dark web with social engineering')
        stub_omni_update_success(business_calendar.id, { chat: chat_channel_business_hours_sample }) do
          params = { 'channel_business_hours' => [
              ticket_business_hours_sample,
              caller_channel_business_hours_sample[:channel_business_hours][0],
              chat_channel_business_hours_sample[:channel_business_hours][0]
          ] }
          put :update, construct_params({ id: business_calendar.id }, params)
          updated_business_calendar = Account.current.business_calendar.where(name: 'Dark web with social engineering').first
          match_json(ember_business_hours_create_pattern(updated_business_calendar, expected_create_response(params).with_indifferent_access))
          assert_equal BusinessCalenderConstants::OMNI_SYNC_STATUS[:inprogress], updated_business_calendar.sync_freshcaller_status
          assert_equal BusinessCalenderConstants::OMNI_SYNC_STATUS[:inprogress], updated_business_calendar.sync_freshchat_status
        end
      end
    end
  end

  def test_update_business_calendar_success_with_background_processing
    enable_emberize_business_hours do
      enable_omni_business_hours_with_sidekiq_fake do
        business_calendar = create_business_calendar(name: 'Dark web with social engineering')
        Admin::BusinessCalendar::OmniSyncWorker.clear
        stub_omni_update_success(business_calendar.id, { chat: chat_channel_business_hours_sample, phone: caller_channel_business_hours_sample }) do
          params = { 'channel_business_hours' => [
              ticket_business_hours_sample,
              caller_channel_business_hours_sample[:channel_business_hours][0],
              chat_channel_business_hours_sample[:channel_business_hours][0]
          ] }
          put :update, construct_params({ id: business_calendar.id }, params)
          Admin::BusinessCalendar::OmniSyncWorker.drain
          assert_requested(:put, business_calendar_update_url(business_calendar.id), times: 1)
          updated_business_calendar = Account.current.business_calendar.where(name: 'Dark web with social engineering').first
          assert_equal BusinessCalenderConstants::OMNI_SYNC_STATUS[:success], updated_business_calendar.sync_freshcaller_status
          assert_equal BusinessCalenderConstants::OMNI_SYNC_STATUS[:success], updated_business_calendar.sync_freshchat_status
        end
      end
    end
  end

  def test_update_business_calendar_freshcaller_failure
   enable_emberize_business_hours do
     enable_omni_business_hours_with_sidekiq_fake do
       params = {
           'channel_business_hours' => [
             ticket_business_hours_sample,
             caller_channel_business_hours_sample[:channel_business_hours][0],
             chat_channel_business_hours_sample[:channel_business_hours][0]
           ]
       }
       business_calendar = create_business_calendar(name: 'Dark web with social engineering')
       Admin::BusinessCalendar::OmniSyncWorker.clear
       stub_bc_update_failure(business_calendar.id)
       stub_chat_business_calendar_update_success(business_calendar.id, chat: chat_channel_business_hours_sample)
       put :update, construct_params({ id: business_calendar.id }, params)
       assert_response 202
       Admin::BusinessCalendar::OmniSyncWorker.drain
       assert_requested(:put, business_calendar_update_url(business_calendar.id), times: 1)
       updated_business_calendar = Account.current.business_calendar.where(name: 'Dark web with social engineering').first
       assert_equal BusinessCalenderConstants::OMNI_SYNC_STATUS[:failed], updated_business_calendar.sync_freshcaller_status
       assert_equal BusinessCalenderConstants::OMNI_SYNC_STATUS[:success], updated_business_calendar.sync_freshchat_status
     end
   end
  ensure
   WebMock.reset!
  end

  def test_update_business_calendar_freshchat_failure
    enable_emberize_business_hours do
      enable_omni_business_hours_with_sidekiq_fake do
        params = {
            'channel_business_hours' => [
              ticket_business_hours_sample,
              caller_channel_business_hours_sample[:channel_business_hours][0],
              chat_channel_business_hours_sample[:channel_business_hours][0]
            ]
        }
        business_calendar = create_business_calendar(name: 'Dark web with social engineering')
        Admin::BusinessCalendar::OmniSyncWorker.clear
        stub_caller_business_calendar_update_success(business_calendar.id, phone: caller_channel_business_hours_sample)
        stub_chat_business_calendar_update_failure(business_calendar.id)
        put :update, construct_params({ id: business_calendar.id }, params)
        assert_response 202
        Admin::BusinessCalendar::OmniSyncWorker.drain
        assert_requested(:put, business_calendar_update_url(business_calendar.id), times: 1)
        updated_business_calendar = Account.current.business_calendar.where(name: 'Dark web with social engineering').first
        assert_equal BusinessCalenderConstants::OMNI_SYNC_STATUS[:success], updated_business_calendar.sync_freshcaller_status
        assert_equal BusinessCalenderConstants::OMNI_SYNC_STATUS[:failed], updated_business_calendar.sync_freshchat_status
      end
    end
  ensure
    WebMock.reset!
  end

  def test_duplicate_name_on_business_calendar_create
    enable_emberize_business_hours do
      enable_omni_business_hours do
        business_calendar = create_business_calendar(name: 'Dark web with social engineering')
        params = dummy_business_calendar_default_params.merge(
          'channel_business_hours' => [
            ticket_business_hours_sample,
            caller_channel_business_hours_sample[:channel_business_hours][0],
            chat_channel_business_hours_sample[:channel_business_hours][0]
          ]
        ).merge(dummy_holiday_data)
        post :create, construct_params(params)
        error_data = [bad_request_error_pattern('name',
                                                'It should be a unique value',
                                                code: 'duplicate_value')]
        assert_response 409
        match_json(description: 'Validation failed', errors: error_data)
      end
    end
  end

  def test_duplicate_name_on_business_calendar_update
    enable_emberize_business_hours do
      enable_omni_business_hours do
        params = {
          'name': 'Dark web with social engineering'
        }
        business_calendar = create_business_calendar(name: 'Dark web with social engineering')
        business_calendar2 = create_business_calendar(name: 'Dark web with social engineering 2')
        put :update, construct_params({ id: business_calendar2.id }, params)
        error_data = [bad_request_error_pattern('name',
                                                'It should be a unique value',
                                                code: 'duplicate_value')]
        assert_response 409
        match_json(description: 'Validation failed', errors: error_data)
      end
    end
  end

  def test_create_business_calendar_for_omni_with_invalid_away_message_for_chat
    enable_emberize_business_hours do
      enable_omni_business_hours do
        params = dummy_business_calendar_default_params.merge(
          'channel_business_hours' => [
            ticket_business_hours_sample,
            caller_channel_business_hours_sample[:channel_business_hours][0],
            chat_channel_business_hours_sample[:channel_business_hours][0].merge(
              "away_message": nil
            )
          ]
        ).merge(dummy_holiday_data)
        post :create, construct_params(params)
        error_data = [bad_request_error_pattern('channel_data[:chat][:away_message]',
                                                "Expecting 'String' but found 'invalid'",
                                                code: 'invalid_value')]
        assert_response 400
        match_json(description: 'Validation failed', errors: error_data)
      end
    end
  end

  def test_create_business_calendar_for_omni_with_missing_away_message_attribute_for_chat
    enable_emberize_business_hours do
      enable_omni_business_hours do
        chat_data = chat_channel_business_hours_sample[:channel_business_hours][0]
        chat_data.delete(:away_message)
        params = dummy_business_calendar_default_params.merge(
          'channel_business_hours' => [
            ticket_business_hours_sample,
            caller_channel_business_hours_sample[:channel_business_hours][0],
            chat_data
          ]
        ).merge(dummy_holiday_data)
        post :create, construct_params(params)
        error_data = [bad_request_error_pattern('channel_data[:chat]',
                                                'Mandatory parameters missing: (away_message)',
                                                code: 'invalid_value')]
        assert_response 400
        match_json(description: 'Validation failed', errors: error_data)
      end
    end
  end

  def test_update_business_calendar_for_omni_with_invalid_away_message_for_chat
    enable_emberize_business_hours do
      enable_omni_business_hours do
        params = {
          'channel_business_hours' => [
            ticket_business_hours_sample,
            caller_channel_business_hours_sample[:channel_business_hours][0],
            chat_channel_business_hours_sample[:channel_business_hours][0].merge(
              "away_message": nil
            )
          ]
        }
        business_calendar = create_business_calendar(name: 'Dark web with social engineering')
        put :update, construct_params({ id: business_calendar.id }, params)
        error_data = [bad_request_error_pattern('channel_data[:chat][:away_message]',
                                                "Expecting 'String' but found 'invalid'",
                                                code: 'invalid_value')]
        assert_response 400
        match_json(description: 'Validation failed', errors: error_data)
      end
    end
  end

  private

    def enable_omni_business_calendar_destroy
      enable_emberize_business_hours do
        enable_omni_business_hours_with_sidekiq_fake do
          yield
        end
      end
    end
    
    def enable_emberize_business_hours
      Account.current.launch :emberize_business_hours
      yield
    ensure
      Account.current.rollback :emberize_business_hours
    end

    # if any stubs are introduced below, please see whether it has to be included in enable_omni_business_hours_with_sidekiq_fake_too
    def enable_omni_business_hours
      Account.any_instance.stubs(:omni_business_calendar?).returns(true)
      Account.any_instance.stubs(:freshcaller_enabled?).returns(true)
      Account.any_instance.stubs(:omni_bundle_id).returns(123)
      Account.any_instance.stubs(:omni_chat_agent_enabled?).returns(true)
      User.any_instance.stubs(:freshid_authorization).returns(
          User.first.authorizations.build(provider: Freshid::Constants::FRESHID_PROVIDER, uid: SecureRandom.uuid))
      AgentObserver.any_instance.stubs(:freshchat_domain).returns('api.freshchat.com')
      fchat_account
      create_freshcaller_account unless Account.current.freshcaller_account
      Sidekiq::Testing.inline! do
        yield
      end
    ensure
      Freshid::V2::Models::User.unstub(:find_by_email)
      Account.any_instance.unstub(:omni_bundle_id)
      Account.any_instance.unstub(:freshcaller_enabled?)
      Account.any_instance.unstub(:omni_business_calendar?)
      Account.any_instance.unstub(:omni_chat_agent_enabled?)
      User.any_instance.unstub(:freshid_authorization)
      AgentObserver.any_instance.unstub(:freshchat_domain)
    end

    def enable_omni_business_hours_with_sidekiq_fake
      Account.any_instance.stubs(:omni_business_calendar?).returns(true)
      Account.any_instance.stubs(:freshcaller_enabled?).returns(true)
      Account.any_instance.stubs(:omni_bundle_id).returns(123)
      Account.any_instance.stubs(:omni_chat_agent_enabled?).returns(true)
      User.any_instance.stubs(:freshid_authorization).returns(
          User.first.authorizations.build(provider: Freshid::Constants::FRESHID_PROVIDER, uid: SecureRandom.uuid))
      AgentObserver.any_instance.stubs(:freshchat_domain).returns('api.freshchat.com')
      fchat_account
      create_freshcaller_account unless Account.current.freshcaller_account
      Sidekiq::Testing.fake! do
        yield
      end
    ensure
      Admin::BusinessCalendar::OmniSyncWorker.clear
      Freshid::V2::Models::User.unstub(:find_by_email)
      Account.any_instance.unstub(:omni_bundle_id)
      Account.any_instance.unstub(:freshcaller_enabled?)
      Account.any_instance.unstub(:omni_business_calendar?)
      Account.any_instance.unstub(:omni_chat_agent_enabled?)
      User.any_instance.unstub(:freshid_authorization)
      AgentObserver.any_instance.unstub(:freshchat_domain)
    end

    def stub_omni_success(args = {})
      stub_chat_bc_success(args)
      stub_caller_bc_create_success(args)
      yield
    ensure
      WebMock.reset!
    end

    def stub_omni_update_success(id, args = {})
      stub_caller_business_calendar_update_success(id, args)
      stub_chat_business_calendar_update_success(id, args)
      yield
    ensure
      WebMock.reset!
    end
end
