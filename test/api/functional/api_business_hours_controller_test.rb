require_relative '../test_helper'
class ApiBusinessHoursControllerTest < ActionController::TestCase
  include Helpers::BusinessHoursTestHelper
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

  def test_show_business_hour_with_feature_disabled
    business_hour = create_business_calendar
    @account.class.any_instance.stubs(:features?).returns(false)
    get :show, construct_params(id: business_hour.id)
    @account.class.any_instance.unstub(:features?)
    assert_response 403
  end

  def test_index_without_privilege
    business_hour = create_business_calendar
    User.any_instance.stubs(:privilege?).returns(false).once
    get :show, construct_params(id: business_hour.id)
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  end

  def test_index_with_link_header
    3.times do
      create_business_calendar
    end
    per_page = Account.current.business_calendar.all.count - 1
    get :index, controller_params(per_page: per_page)
    assert_response 200
    assert JSON.parse(response.body).count == per_page
    assert_equal "<http://#{@request.host}/api/v2/business_hours?per_page=#{per_page}&page=2>; rel=\"next\"", response.headers['Link']

    get :index, controller_params(per_page: per_page, page: 2)
    assert_response 200
    assert JSON.parse(response.body).count == 1
    assert_nil response.headers['Link']
  end
end
