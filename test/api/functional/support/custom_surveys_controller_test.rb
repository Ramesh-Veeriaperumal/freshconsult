require_relative '../../test_helper'
require_relative '../../../core/helpers/users_test_helper'
class Support::CustomSurveysControllerTest < ActionController::TestCase
  include SurveysTestHelper
  include CoreUsersTestHelper
  include ControllerTestHelper

  def setup
    super
    Account.stubs(:current).returns(Account.first)
    @survey = Account.current.surveys.first
    @survey_handle = Account.current.tickets.first.survey_handles.build
    @survey_handle.survey = @survey
    @survey_handle.id_token = rand(10_000)
    @survey_handle.save!
    @rating = 103
  end

  def teardown
    Account.unstub(:current)
  end

  def test_when_agent_logged_in_for_csat_redirect
    user = add_test_agent(@account, role: Role.find_by_name('Administrator').id)
    login_as(user)
    get :hit, controller_params(survey_code: @survey_handle.id_token)
    assert_response 302
    log_out
  end
end
