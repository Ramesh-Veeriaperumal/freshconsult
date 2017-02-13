require_relative '../../test_helper'
class Ember::SurveysControllerTest < ActionController::TestCase
  include SurveysTestHelper

  def create_survey_questions
    survey = Account.current.custom_surveys.first # Needs to be changed to Account.current.survey once surveys are enabled for singups
    3.times do |x|
      sq = survey.survey_questions.create('type' => 'survey_radio', 'field_type' => 'custom_survey_radio', 'label' => ' How would you rate your overallsatisfaction for the resolution provided by the agent?', 'name' => "cf_how_would_you_rate_your_overallsatisfaction_for_the_resolution_provided_by_the_agent#{x}", 'custom_field_choices_attributes' => [{ 'value' => 'Extremelydissatisfied', 'face_value' => -103, 'position' => 1, '_destroy' => 0 }, { 'value' => 'Neithersatisfied nor dissatisfied', 'face_value' => 100, 'position' => 2, '_destroy' => 0 }, { 'value' => 'Extremely satisfied', 'face_value' => 103, 'position' => 3, '_destroy' => 0 }], 'action' => 'create', 'default' => false, 'position' => 1)
      sq.column_name = "cf_int0#{x + 2}"
      sq.save
    end
  end

  def setup
    super
    create_survey_questions
    stub_custom_survey true
  end

  def teardown
    unstub_custom_survey
  end

  def wrap_cname(params)
    { survey: params }
  end

  def test_index
    get :index, controller_params(version: 'private')
    assert_response 200
    assert JSON.parse(response.body).count > 0
    match_json(index_survey_pattern(@account.custom_surveys.undeleted, true))
  end

  def test_index_without_manage_tickets
    User.any_instance.stubs(:privilege?).with(:manage_tickets).returns(false)
    get :index, controller_params(version: 'private')
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  ensure
    User.any_instance.unstub(:privilege?)
  end
end
