require_relative '../test_helper'
class SurveysControllerTest < ActionController::TestCase
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

  def test_create_custom_survey
    post :create, construct_params({ id: ticket.display_id }, rating: 103)
    assert_response 201
    match_json(survey_custom_rating_pattern(CustomSurvey::SurveyResult.last))
  end

  def test_create_survey_with_feedback
    post :create, construct_params({ id: ticket.display_id }, rating: 103, feedback: 'Feedback given Surveys')
    assert_response 201
    match_json(survey_custom_rating_pattern(CustomSurvey::SurveyResult.last))
    res = JSON.parse(response.body)
    feedback = res['feedback']
    assert 'Feedback given Surveys', feedback
  end

  def test_create_survey_without_rating
    post :create, construct_params({ id: ticket.display_id },  feedback: 'Feedback given Surveys')
    assert_response 400
    match_json([bad_request_error_pattern('rating', :not_included, code: :missing_field, list: '-103,100,103')])
  end

  def test_create_with_invalid_data_type
    post :create, construct_params({ id: ticket.display_id }, rating: 'test', feedback: [])
    assert_response 400
    match_json([bad_request_error_pattern('rating', :not_included, list: '-103,100,103'),
                bad_request_error_pattern('feedback', :datatype_mismatch, expected_data_type: String, prepend_msg: :input_received, given_data_type: Array)])
  end

  def test_view_list_of_surveys
    3.times do
      post :create, construct_params({ id: ticket.display_id }, rating: 103, feedback: 'Feedback given Surveys')
      assert_response 201
    end
    get :survey_results, controller_params(id: ticket.display_id)
    pattern = []
    CustomSurvey::SurveyResult.all.each do |sr|
      pattern << survey_custom_rating_pattern(sr)
    end
    assert_response 200
    match_json(pattern)
  end

  def test_create_with_custom_ratings
    post :create, construct_params({ id: ticket.display_id }, rating: 103, feedback: 'Feedback given Surveys', custom_ratings: { 'question_2' => -103, 'question_3' => 100 })
    assert_response 201
    match_json(survey_custom_rating_pattern(CustomSurvey::SurveyResult.last))
  end

  def test_create_with_invalid_custom_ratings
    post :create, construct_params({ id: ticket.display_id }, rating: 103, feedback: 'Feedback given Surveys', custom_ratings: { 'question_10' => -103 })
    assert_response 400
    match_json([bad_request_error_pattern('question_10',  :invalid_field)])
  end

  def test_create_with_invalid_custom_ratings_type
    post :create, construct_params({ id: ticket.display_id }, rating: 103, feedback: 'Feedback given Surveys', custom_ratings: { 'question_3' => 'Test' })
    assert_response 400
    match_json([bad_request_error_pattern('question_3', :not_included, list: '-103,100,103')])
  end

  def test_create_with_invalid_custom_ratings_value
    post :create, construct_params({ id: ticket.display_id }, rating: 103, feedback: 'Feedback given Surveys', custom_ratings: { 'question_3' => -102, 'question_2' => 110 })
    assert_response 400
    match_json([bad_request_error_pattern('question_3', :not_included, list: '-103,100,103'),
                bad_request_error_pattern('question_2', :not_included, list: '-103,100,103')])
  end

  def test_create_with_invalid_custom_ratings_data_type
    post :create, construct_params({ id: ticket.display_id }, rating: 103, feedback: 'Feedback given Surveys', custom_ratings: [-102, 110])
    assert_response 400
    match_json([bad_request_error_pattern('custom_ratings', :datatype_mismatch, expected_data_type: 'key/value pair', prepend_msg: :input_received, given_data_type: Array)])
  end

  def test_create_with_default_question_in_custom_ratings
    post :create, construct_params({ id: ticket.display_id }, rating: 103, feedback: 'Feedback given Surveys', custom_ratings: { 'question_1' => 103 })
    assert_response 400
    match_json([bad_request_error_pattern('question_1',  :invalid_field)])
  end

  def test_show_activated_survey
    get :active_survey, controller_params
    assert_response 200
    match_json(active_custom_survey_pattern(Account.current.survey))
  end

  def test_show_classic_activated_survey
    stub_custom_survey false
    get :active_survey, controller_params
    unstub_custom_survey
    assert_response 200
    match_json(active_classic_survey_rating(Account.current.survey))
  end

  def test_view_all_survey_results_with_user_filter
    user_id = User.last.id
    CustomSurvey::SurveyResult.update_all(customer_id: user_id)
    get :index, controller_params(user_id: user_id)
    pattern = []
    CustomSurvey::SurveyResult.all.each do |sr|
      pattern << survey_custom_rating_pattern(sr)
    end
    assert_response 200
    match_json(pattern)
  end

  def test_view_all_survey_with_invalid_filter_values
    get :index, controller_params(user_id: 'test', created_since: 1000)
    assert_response 400
    match_json([bad_request_error_pattern('user_id', :datatype_mismatch, expected_data_type:  'Positive Integer'),
                bad_request_error_pattern('created_since', :invalid_date, accepted: :'combined date and time ISO8601')])
  end

  def test_view_all_survey_with_invalid_field
    get :index, controller_params(customer_id: 'test')
    assert_response 400
    match_json([bad_request_error_pattern('customer_id',  :invalid_field)])
  end

  def test_view_all_without_filters
    get :index, controller_params
    pattern = []
    CustomSurvey::SurveyResult.all.each do |sr|
      pattern << survey_custom_rating_pattern(sr)
    end
    assert_response 200
    response_json = JSON.parse(response.body)
    assert_equal response_json.size, CustomSurvey::SurveyResult.count
    match_json(pattern)
  end

  def test_view_with_features_disabled
    @account.class.any_instance.stubs(:features?).returns(false)
    get :index, controller_params
    @account.class.any_instance.unstub(:features?)
    assert_response 403
    match_json(request_error_pattern(:require_feature, feature: 'surveys,survey_links'.titleize))
  end

  def test_create_without_manage_tickets_privilege
    User.any_instance.stubs(:privilege?).with(:manage_tickets).returns(false).at_most_once
    post :create, construct_params({ id: ticket.display_id }, rating: 103)
    User.any_instance.unstub(:privilege?)
    assert_response 403
    match_json(request_error_pattern(:access_denied))
    ensure
      User.any_instance.unstub(:privilege?)
  end

  def test_create_without_ticket_privilege
    User.any_instance.stubs(:has_ticket_permission?).returns(false)
    post :create, construct_params({ id: ticket.display_id }, rating: 103)
    User.any_instance.unstub(:has_ticket_permission?)
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  end

  def test_index_without_admin_privilege
    User.any_instance.stubs(:privilege?).with(:admin_tasks).returns(false).at_most_once
    get :index, controller_params
    assert_response 403
    match_json(request_error_pattern(:access_denied))
    ensure
      User.any_instance.unstub(:privilege?)
  end

  def test_index_with_created_at_filter
    CustomSurvey::SurveyResult.update_all(created_at: 2.days.ago)
    CustomSurvey::SurveyResult.first.update_attributes(created_at: DateTime.now)
    get :index, controller_params(created_since: 1.days.ago.iso8601)
    pattern = []
    assert_response 200
    match_json(pattern)
    response = parse_response @response.body
    assert_equal 0, response.size
  end
end
