require_relative '../test_helper'
class ApiBusinessCalendarsControllerTest < ActionController::TestCase
  def wrap_cname(params)
    { api_business_calendar: params }
  end

  def test_index_load_business_calendars
    get :index, request_params
    assert_equal BusinessCalendar.all, assigns(:items)
  end

  def test_index
    get :index, request_params
    pattern = []
    Account.current.business_calendar.all.each do |bc|
      pattern << business_calendar_index_pattern(BusinessCalendar.find(bc.id))
    end
    assert_response :success
    match_json(pattern)
  end

  def test_show_business_calendar
    business_calendar = create_business_calendar
    get :show, construct_params(id: business_calendar.id)
    assert_response :success
    match_json(business_calendar_pattern(BusinessCalendar.find(business_calendar.id)))
  end

  def test_handle_show_request_for_missing_business_calendar
    get :show, construct_params(id: 2000)
    assert_response :missing
    assert_equal ' ', response.body
  end

  def test_handle_show_request_for_invalid_business_calendar_id
    get :show, construct_params(id: Faker::Name.name)
    assert_response :missing
    assert_equal ' ', response.body
  end

  def test_show_business_calendar_with_feature_disabled
    business_calendar = create_business_calendar
    @account.class.any_instance.stubs(:features_included?).returns(false)
    get :show, construct_params(id: business_calendar.id)
    @account.class.any_instance.unstub(:features_included?)
    assert_response :forbidden
  end
end
