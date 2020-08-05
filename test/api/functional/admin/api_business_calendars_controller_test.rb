require_relative '../../test_helper.rb'
class Admin::ApiBusinessCalendarsControllerTest < ActionController::TestCase
  include BusinessHoursTestHelper

  def setup
    super
    Account.stubs(:current).returns(Account.first)
    User.stubs(:current).returns(User.first)
    Account.any_instance.stubs(:multiple_business_hours_enabled?).returns(true)
  end

  def teardown
    Account.unstub(:current)
    User.unstub(:current)
    Account.any_instance.unstub(:multiple_business_hours_enabled?)
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
      business_calendar_id = 32424322
      business_calendar = Account.current.business_calendar.where(id: business_calendar_id).first
      skip if business_calendar
      get :show, controller_params(id: business_calendar_id)
      assert_response 404
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
