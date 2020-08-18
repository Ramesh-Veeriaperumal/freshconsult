require_relative '../../test_helper.rb'
class Admin::HolidaysControllerTest < ActionController::TestCase
  def setup
    super
    Account.stubs(:current).returns(Account.first)
    User.stubs(:current).returns(User.first)
  end

  def teardown
    Account.unstub(:current)
    User.unstub(:current)
  end

  def test_holidays_without_enabling_feature
    get :show, controller_params(id: 'IN')
    assert_response 403
  end

  def test_holidays_with_feature_enabled
    enable_emberize_business_hours do
      IntegrationServices::Services::GoogleService.any_instance.stubs(:receive_list_holidays).returns(holidays: [['Republic Day', 'Jan 26'], ['Independence Day', 'Aug 15']], error: false)
      get :show, controller_params(id: 'IN')
      response = JSON.parse(@response.body)
      assert_equal response.size, 2
      match_json(holidays_list_pattern(response))
      assert_response 200
    end
  end

  def test_holidays_with_invalid_country_id
    enable_emberize_business_hours do
      get :show, controller_params(id: 'INDIA')
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

    def holidays_list_pattern(response)
      pattern = []
      response.each do |holiday|
        pattern << { name: String, date: String }
      end
      pattern
    end
end
