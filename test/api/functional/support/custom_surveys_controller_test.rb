require_relative '../../test_helper'
require_relative '../../../core/helpers/users_test_helper'
class Support::CustomSurveysControllerTest < ActionController::TestCase
  include SurveysTestHelper
  include CoreUsersTestHelper
  include ControllerTestHelper

  def setup
    super
    Account.stubs(:current).returns(Account.first)
    Language.stubs(:current).returns(Language.find_by_code('en'))
    @survey = Account.current.surveys.first
    @survey_handle = Account.current.tickets.first.survey_handles.build
    @survey_handle.survey = @survey
    @survey_handle.id_token = rand(10_000)
    @survey_handle.save!
    @rating = 103
  end

  def teardown
    Language.unstub(:current)
    Account.unstub(:current)
    super
  end

  def test_when_agent_logged_in_for_csat_redirect
    login_admin
    get :hit, controller_params(survey_code: @survey_handle.id_token)
    assert_response 302
    log_out
  end

  def test_encryption_and_decryption
    @controller.stubs(:current_user).returns(nil)
    get :hit, controller_params(survey_code: @survey_handle.id_token, rating: 103)
    assert_response 200
    response_data = JSON.parse(response.body)
    assert response_data.is_a?(Hash), true.to_s
    assert response_data['submit_url'].is_a?(String), true.to_s
    submit_url = response_data['submit_url'].split('/')
    assert submit_url.count, 5.to_s
    post :create, construct_params(survey_result: submit_url[3])
    assert_response 200
    feedback = JSON.parse(response.body)
    assert feedback['thanks_message'], 'Thank you. Your feedback has been sent.'
  ensure
    @controller.unstub(:current_user)
  end

  def test_encryption_and_decryption_with_modified_encryption_data
    @controller.stubs(:current_user).returns(nil)
    get :hit, controller_params(survey_code: @survey_handle.id_token, rating: 103)
    assert_response 200
    response_data = JSON.parse(response.body)
    assert response_data.is_a?(Hash), true.to_s
    assert response_data['submit_url'].is_a?(String), true.to_s
    submit_url = response_data['submit_url'].split('/')
    assert submit_url.count, 5.to_s
    modified_data = submit_url[3].to_s + 'sample_data'
    post :create, construct_params(survey_result: modified_data)
    assert_response 302
  ensure
    @controller.unstub(:current_user)
  end
end
