require_relative '../../api/test_helper'

class ReportsControllerTest < ActionController::TestCase
  def test_reports_controller
    Account.any_instance.stubs(:disable_old_reports_enabled?).returns(false)
    get :index
    assert_response 200
  ensure
    Account.any_instance.unstub(:disable_old_reports_enabled?)
  end

  def test_reports_controller_with_diabled_lp_enabled
    Account.any_instance.stubs(:disable_old_reports_enabled?).returns(true)
    get :index
    assert_response 404
  ensure
    Account.any_instance.unstub(:disable_old_reports_enabled?)
  end
end
