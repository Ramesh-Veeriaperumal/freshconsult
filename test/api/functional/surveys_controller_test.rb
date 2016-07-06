require_relative '../test_helper'
class SurveysControllerTest < ActionController::TestCase
  include SurveysTestHelper

  attr_accessor :number

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
    get :index, controller_params
    assert_response 200
    assert JSON.parse(response.body).count > 0
    match_json(index_survey_pattern(@account.custom_surveys.undeleted))
  end

  def test_index_with_active_filter
    get :index, controller_params({ state: 'active' }, {})
    assert_response 200
    assert JSON.parse(response.body).count > 0
    match_json(index_survey_pattern(Array.wrap(@account.custom_surveys.active.with_questions_and_choices.first)))
  end

  def test_index_with_active_filter_for_default_survey
    stub_custom_survey false
    get :index, controller_params({ state: 'active' }, {})
    assert_response 200
    assert JSON.parse(response.body).count == 1
    match_json([active_classic_survey_rating(@account.survey)])
  ensure
    unstub_custom_survey
  end

  def test_index_for_default_survey
    stub_custom_survey false
    get :index, controller_params
    assert_response 200
    assert JSON.parse(response.body).count == 1
    match_json([active_classic_survey_rating(@account.survey)])
  ensure
    unstub_custom_survey
  end

  def test_index_with_active_filter_for_default_survey_without_survey_link_feature
    stub_custom_survey false
    Account.any_instance.stubs(:features?).with(:surveys).returns(true).once
    Account.any_instance.stubs(:features?).with(:survey_links).returns(false).once
    get :index, controller_params({state: 'active'}, {})
    assert_response 200
    assert JSON.parse(response.body).count == 0
  ensure
    Account.any_instance.unstub(:features?)
    unstub_custom_survey
  end

  def test_index_without_privilege
    User.any_instance.stubs(:privilege?).with(:admin_tasks).returns(false).at_most_once
    get :index, controller_params
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  ensure
    User.any_instance.unstub(:privilege?)
  end

  def test_index_without_feature
    Account.any_instance.stubs(:features?).returns(false).once
    get :index, controller_params
    assert_response 403
    match_json(request_error_pattern(:require_feature, feature: 'Surveys'))
  ensure
    Account.any_instance.unstub(:features?)
  end

   def test_index_with_invalid_filter
    get :index, controller_params({ test: 'junk' }, {})
    assert_response 400
    match_json([bad_request_error_pattern('test', :invalid_field)])
  end

  def test_index_with_invalid_filter_value
    get :index, controller_params({ state: 'junk' }, {})
    assert_response 400
    match_json([bad_request_error_pattern('state', :not_included, list: 'active')])
  end

  def test_index_with_pagination
    3.times do
      @number ||= 1
      @number += @number
      create_survey(@number)
    end
    get :index, controller_params(per_page: 1)
    assert_response 200
    assert JSON.parse(response.body).count == 1
    get :index, controller_params(per_page: 1)
    assert_response 200
    assert JSON.parse(response.body).count == 1
  end

  def test_index_with_pagination_exceeds_limit
    get :index, controller_params(per_page: 101)
    assert_response 400
    match_json([bad_request_error_pattern('per_page', :per_page_invalid, max_value: 100)])
  end

  def test_index_with_link_header
    3.times do
      @number ||= 1
      @number += @number
      create_survey(@number)
    end
    surveys = @account.custom_surveys.undeleted
    per_page = surveys.count - 1
    get :index, controller_params(per_page: per_page)
    assert_response 200
    assert JSON.parse(response.body).count == per_page
    match_json(index_survey_pattern(surveys.take(per_page)))
    assert_equal "<http://#{@request.host}/api/v2/surveys?per_page=#{per_page}&page=2>; rel=\"next\"", response.headers['Link']

    get :index, controller_params(per_page: per_page, page: 2)
    assert_response 200
    assert JSON.parse(response.body).count == 1
    assert_nil response.headers['Link']
  end


end
