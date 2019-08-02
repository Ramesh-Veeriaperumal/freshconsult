require_relative '../../test_helper'
class Admin::CustomTranslationsControllerTest < ActionController::TestCase
  include SurveysTestHelper

  MODULES = ['surveys'].freeze

  def stub_for_custom_translations
    Account.current.add_feature(:custom_translations)
    Account.current.launch :csat_translations
    Account.current.launch :redis_picklist_id
  end

  def unstub_for_custom_translations
    Account.current.revoke_feature(:custom_translations)
    Account.current.rollback :csat_translations
    Account.current.rollback :redis_picklist_id
  end

  def create_survey_questions(survey)
    3.times do |x|
      sq = survey.survey_questions.create('type' => 'survey_radio', 'field_type' => 'custom_survey_radio', 'label' => ' How would you rate your overallsatisfaction for the resolution provided by the agent?', 'name' => "cf_how_would_you_rate_your_overallsatisfaction_for_the_resolution_provided_by_the_agent#{x}", 'custom_field_choices_attributes' => [{ 'value' => 'Extremelydissatisfied', 'face_value' => -103, 'position' => 1, '_destroy' => 0 }, { 'value' => 'Neithersatisfied nor dissatisfied', 'face_value' => 100, 'position' => 2, '_destroy' => 0 }, { 'value' => 'Extremely satisfied', 'face_value' => 103, 'position' => 3, '_destroy' => 0 }], 'action' => 'create', 'default' => false, 'position' => 1)
      sq.column_name = "cf_int0#{x + 2}"
      sq.save
    end
  end

  def assert_survey(survey, response_hash)
    assert_equal response_hash['title_text'], survey.title_text
    assert_equal response_hash['comments_text'], survey.comments_text
    assert_equal response_hash['thanks_text'], survey.thanks_text
    assert_equal response_hash['feedback_response_text'], survey.feedback_response_text
    # Default question and choices
    default_question = survey.default_question
    assert_equal response_hash['default_question']['question'], default_question.label
    default_question.choices.each do |choice|
      assert_equal response_hash['default_question']['choices'][choice[:face_value]], choice[:value]
    end
    # Additional questions and choices
    additional_questions = survey.survey_questions.reject(&:default)
    additional_questions.each do |question|
      assert_equal response_hash['additional_questions']["question_#{question.id}"], question.label
    end
    additional_questions.first.choices.each do |choice|
      assert_equal response_hash['additional_questions']['choices'][choice[:face_value]], choice[:value]
    end
  end

  def test_primary_download_for_surveys_with_id
    stub_for_custom_translations
    create_survey(1, true)
    survey = Account.current.custom_surveys.last
    create_survey_questions(survey)
    language = Account.current.language
    get :download, controller_params('object_type' => 'surveys', 'object_id' => survey.id)
    response_hash = YAML.safe_load(response.body)[language]['custom_translations']['surveys']["survey_#{survey.id}"]
    assert_survey(survey, response_hash)
    survey.destroy
    unstub_for_custom_translations
  end

  def test_primary_download_with_invalid_id
    stub_for_custom_translations
    create_survey(1, true)
    survey = Account.current.custom_surveys.last
    survey_id = Account.current.custom_surveys.pluck(:id).max
    object_id = survey_id.nil? ? 2 : survey_id + 10
    get :download, controller_params('object_type' => 'surveys', 'object_id' => object_id)
    assert_response 400
    match_json([bad_request_error_pattern('object_id', :invalid_object_id, object: 'surveys')])
    survey.destroy
    unstub_for_custom_translations
  end

  def test_primary_download_with_invalid_type
    stub_for_custom_translations
    create_survey(1, true)
    survey = Account.current.custom_surveys.last
    object_type = Faker::Lorem.words(1)
    get :download, controller_params('object_type' => object_type, 'object_id' => survey.id)
    assert_response 400
    match_json([bad_request_error_pattern('object_type', :not_included, list: Admin::CustomTranslationsConstants::MODULE_MODEL_MAPPINGS.keys.join(','))])
    survey.destroy
    unstub_for_custom_translations
  end

  def test_primary_download_with_id_given_type_nil
    stub_for_custom_translations
    create_survey(1, true)
    survey = Account.current.custom_surveys.last
    get :download, controller_params('object_id' => 123)
    match_json([bad_request_error_pattern('object_type', :missing_param, code: :missing_field)])
    survey.destroy
    unstub_for_custom_translations
  end
end
