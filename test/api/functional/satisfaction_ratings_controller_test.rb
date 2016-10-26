require_relative '../test_helper'
class SatisfactionRatingsControllerTest < ActionController::TestCase
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
    { satisfaction_rating: params }
  end

  def test_create_custom_survey
    post :create, construct_params({ id: ticket.display_id }, ratings: { 'default_question' => 103 })
    assert_response 201
    match_json(survey_custom_rating_pattern(CustomSurvey::SurveyResult.last))
  end

  def test_create_survey_with_feedback
    post :create, construct_params({ id: ticket.display_id }, ratings: { 'default_question' => 103 }, feedback: 'Feedback given Surveys')
    assert_response 201
    match_json(survey_custom_rating_pattern(CustomSurvey::SurveyResult.last))
    res = JSON.parse(response.body)
    feedback = res['feedback']
    assert 'Feedback given Surveys', feedback
  end

  def test_create_survey_without_rating
    post :create, construct_params({ id: ticket.display_id },  feedback: 'Feedback given Surveys')
    assert_response 400
    match_json([bad_request_error_pattern('ratings', :missing_field)])
  end

  def test_create_with_invalid_data_type
    post :create, construct_params({ id: ticket.display_id }, ratings: { 'default_question' => 'test' }, feedback: [])
    assert_response 400
    match_json([bad_request_error_pattern_with_nested_field('ratings', 'default_question', :not_included, list: @account.survey.survey_questions.first.face_values.join(',')),
                bad_request_error_pattern('feedback', :datatype_mismatch, expected_data_type: String, prepend_msg: :input_received, given_data_type: Array)])
  end

  def test_view_list_of_surveys
    ticket_obj = create_ticket
    result = []
    1.times do
      result << create_survey_result(ticket_obj, 3)
    end
    get :survey_results, controller_params(id: ticket_obj.display_id)
    assert_response 200
    response_json = JSON.parse(response.body)
    assert_equal 1, response_json.size
    pattern = []
    result.each do |sr|
      pattern << survey_custom_rating_pattern(sr)
    end
    match_json(pattern)
  end

  def test_create_with_custom_ratings
    post :create, construct_params({ id: ticket.display_id }, ratings: { 'default_question' => 103, 'question_2' => -103, 'question_3' => 100 }, feedback: 'Feedback given Surveys')
    assert_response 201
    match_json(survey_custom_rating_pattern(CustomSurvey::SurveyResult.last))
  end

  def test_create_without_default_question
    post :create, construct_params({ id: ticket.display_id }, ratings: { 'question_2' => -103, 'question_3' => 100 }, feedback: 'Feedback given Surveys')
    assert_response 400
    match_json([bad_request_error_pattern_with_nested_field('ratings', 'default_question', :not_included, code: :missing_field, list: @account.survey.survey_questions.first.face_values.join(','))])
  end

  def test_create_with_invalid_custom_ratings
    post :create, construct_params({ id: ticket.display_id }, ratings: { 'default_question' => 103, 'question_10' => -103 }, feedback: 'Feedback given Surveys')
    assert_response 400
    match_json([bad_request_error_pattern('question_10',  :invalid_field)])
  end

  def test_create_with_invalid_custom_ratings_type
    post :create, construct_params({ id: ticket.display_id }, ratings: { 'default_question' => 103, 'question_3' => 'Test' }, feedback: 'Feedback given Surveys')
    assert_response 400
    match_json([bad_request_error_pattern_with_nested_field('ratings', 'question_3', :not_included, list: @account.survey.survey_questions.first.face_values.join(','))])
  end

  def test_create_with_invalid_custom_ratings_value
    post :create, construct_params({ id: ticket.display_id }, ratings: { 'default_question' => 103, 'question_3' => -102, 'question_2' => 110 }, feedback: 'Feedback given Surveys')
    assert_response 400
    match_json([bad_request_error_pattern_with_nested_field('ratings', 'question_3', :not_included, list: @account.survey.survey_questions.first.face_values.join(',')),
                bad_request_error_pattern_with_nested_field('ratings', 'question_2', :not_included, list: @account.survey.survey_questions.first.face_values.join(','))])
  end

  def test_create_with_invalid_custom_ratings_data_type
    post :create, construct_params({ id: ticket.display_id }, ratings: [-102, 110], feedback: 'Feedback given Surveys')
    assert_response 400
    match_json([bad_request_error_pattern('ratings', :datatype_mismatch, expected_data_type: 'key/value pair', prepend_msg: :input_received, given_data_type: Array)])
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
    match_json(request_error_pattern(:require_feature, feature: 'surveys'.titleize))
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
    present_date_time = DateTime.now
    survey_result = CustomSurvey::SurveyResult.first
    survey_result.created_at = present_date_time
    survey_result.save
    get :index, controller_params(created_since: present_date_time.iso8601)
    assert_response 200
    response = parse_response @response.body
    assert_equal 1, response.size
  end

  def test_view_all_survey_with_invalid_user_ids
    get :index, controller_params(user_id: 1000)
    assert_response 400
    match_json([bad_request_error_pattern('user_id', :absent_in_db, resource: 'contact', attribute: 'user_id')])
  end

  def test_create_satisfaction_rating_without_active_survey
    deactivate_survey
    post :create, construct_params({ id: ticket.display_id }, rating: 103)
    activate_survey
    assert_response 403
    match_json(request_error_pattern(:action_restricted, action: 'create', reason: 'no survey is enabled'))
  end

  def test_view_satisfaction_ratings_when_survey_link_feature_disabled
    delete_survey_link_feature
    get :index, controller_params
    create_survey_link_feature
    pattern = []
    CustomSurvey::SurveyResult.all.each do |sr|
      pattern << survey_custom_rating_pattern(sr)
    end
    assert_response 200
    response_json = JSON.parse(response.body)
    assert_equal response_json.size, CustomSurvey::SurveyResult.count
    match_json(pattern)
  end

  def test_create_classic_survey_with_survey_link_disabled
    stub_custom_survey false
    deactivate_survey
    post :create, construct_params({ id: ticket.display_id }, rating: 103)
    activate_survey
    unstub_custom_survey
    assert_response 403
    match_json(request_error_pattern(:action_restricted, action: 'create', reason: 'no survey is enabled'))
  end

  def test_create_with_features_disabled
    @account.class.any_instance.stubs(:features?).returns(false)
    post :create, construct_params({ id: ticket.display_id }, rating: 103)
    @account.class.any_instance.unstub(:features?)
    assert_response 403
    match_json(request_error_pattern(:require_feature, feature: 'surveys,survey_links'.titleize))
  end

  def test_view_with_survey_deactivated
    deactivate_survey
    get :index, controller_params
    activate_survey
    pattern = []
    CustomSurvey::SurveyResult.all.each do |sr|
      pattern << survey_custom_rating_pattern(sr)
    end
    assert_response 200
    response_json = JSON.parse(response.body)
    assert_equal response_json.size, CustomSurvey::SurveyResult.count
    match_json(pattern)
  end
end
