require_relative '../test_helper'
class ApiBusinessHoursControllerTest < ActionController::TestCase
  include BusinessHoursTestHelper

  def setup
    Account.any_instance.stubs(:multiple_business_hours_enabled?).returns(:true)
    super
  end

  def teardown
    Account.any_instance.unstub(:multiple_business_hours_enabled?)
  end

  def wrap_cname(params)
    { api_business_hour: params }
  end

  def test_index
    3.times do
      create_business_calendar
    end
    get :index, controller_params
    pattern = []
    Account.current.business_calendar.order(:name).all.each do |bc|
      pattern << business_hour_index_pattern(bc)
    end
    assert_response 200
    match_json(pattern.ordered!)
  end

  def test_show_business_hour
    business_hour = create_business_calendar
    get :show, construct_params(id: business_hour.id)
    assert_response 200
    match_json(business_hour_pattern(BusinessCalendar.find(business_hour.id)))
  end

  def test_handle_show_request_for_missing_business_hour
    get :show, construct_params(id: 2000)
    assert_response 404
    assert_equal ' ', response.body
  end

  def test_handle_show_request_for_invalid_business_hour_id
    get :show, construct_params(id: Faker::Name.name)
    assert_response 404
    assert_equal ' ', response.body
  end

  def test_index_without_privilege
    business_hour = create_business_calendar
    User.any_instance.stubs(:privilege?).returns(false)
    get :show, construct_params(id: business_hour.id)
    assert_response 403
    match_json(request_error_pattern(:access_denied))
    User.any_instance.unstub(:privilege?)
  end

  def test_index_with_link_header
    3.times do
      create_business_calendar
    end
    per_page = Account.current.business_calendar.all.count - 1
    get :index, controller_params(per_page: per_page, page: 1)
    assert_response 200
    assert JSON.parse(response.body).count == per_page
    assert_equal "<http://#{@request.host}/api/v2/business_hours?per_page=#{per_page}&page=2>; rel=\"next\"", response.headers['Link']

    get :index, controller_params(per_page: per_page, page: 2)
    assert_response 200
    assert JSON.parse(response.body).count == 1
    assert_nil response.headers['Link']
  end

  def test_index_with_pagination
    5.times do
      create_business_calendar
    end
    per_page = 2
    get :index, controller_params(per_page: per_page, page: 2)
    assert JSON.parse(response.body).count == per_page
    assert_response 200
  end

  def test_index_with_out_pagination
    5.times do
      create_business_calendar
    end
    get :index, controller_params
    assert JSON.parse(response.body).count == Account.current.business_calendar.count
    assert_response 200
  end
end
