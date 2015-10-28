require_relative '../test_helper'
class ApiBusinessCalendarsControllerTest < ActionController::TestCase
  include Helpers::BusinessCalendarsTestHelper
  def wrap_cname(params)
    { api_business_calendar: params }
  end

  def test_index
    3.times do
      create_business_calendar
    end
    get :index, request_params
    pattern = []
    Account.current.business_calendar.order(:name).all.each do |bc|
      pattern << business_calendar_index_pattern(bc)
    end
    assert_response 200
    match_json(pattern.ordered!)
  end

  def test_show_business_calendar
    business_calendar = create_business_calendar
    get :show, construct_params(id: business_calendar.id)
    assert_response 200
    match_json(business_calendar_pattern(BusinessCalendar.find(business_calendar.id)))
  end

  def test_handle_show_request_for_missing_business_calendar
    get :show, construct_params(id: 2000)
    assert_response 404
    assert_equal ' ', response.body
  end

  def test_handle_show_request_for_invalid_business_calendar_id
    get :show, construct_params(id: Faker::Name.name)
    assert_response 404
    assert_equal ' ', response.body
  end

  def test_show_business_calendar_with_feature_disabled
    business_calendar = create_business_calendar
    @account.class.any_instance.stubs(:features_included?).returns(false)
    get :show, construct_params(id: business_calendar.id)
    @account.class.any_instance.unstub(:features_included?)
    assert_response 403
  end

  def test_index_without_privilege
    business_calendar = create_business_calendar
    User.any_instance.stubs(:privilege?).returns(false).once
    get :show, construct_params(id: business_calendar.id)
    assert_response 403
    match_json(request_error_pattern('access_denied'))
  end

  def test_index_with_link_header
    3.times do
      create_business_calendar
    end
    per_page = Account.current.business_calendar.all.count - 1
    get :index, construct_params(per_page: per_page)
    assert_response 200
    assert JSON.parse(response.body).count == per_page
    assert_equal "<http://#{@request.host}/api/v2/business_calendars?per_page=#{per_page}&page=2>; rel=\"next\"", response.headers['Link']

    get :index, construct_params(per_page: per_page, page: 2)
    assert_response 200
    assert JSON.parse(response.body).count == 1
    assert_nil response.headers['Link']
  end
end
