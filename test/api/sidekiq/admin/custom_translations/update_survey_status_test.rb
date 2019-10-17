require_relative '../../../unit_test_helper'
require_relative '../../../helpers/surveys_test_helper'
require 'sidekiq/testing'
require 'faker'
Sidekiq::Testing.fake!
class Admin::CustomTranslationsControllerTest < ActionController::TestCase
  include SurveysTestHelper
  SURVEY_STATUS = {
    untranslated: 0,
    translated: 1,
    outdated: 2,
    incomplete: 3
  }.freeze

  def setup
    @account = Account.first.make_current
  end

  def create_survey_questions(survey)
    3.times do |x|
      sq = survey.survey_questions.create('type' => 'survey_radio', 'field_type' => 'custom_survey_radio', 'label' => ' How would you rate your overallsatisfaction for the resolution provided by the agent?', 'name' => "cf_how_would_you_rate_your_overallsatisfaction_for_the_resolution_provided_by_the_agent#{x}", 'custom_field_choices_attributes' => [{ 'value' => 'Extremelydissatisfied', 'face_value' => -103, 'position' => 1, '_destroy' => 0 }, { 'value' => 'Neithersatisfied nor dissatisfied', 'face_value' => 100, 'position' => 2, '_destroy' => 0 }, { 'value' => 'Extremely satisfied', 'face_value' => 103, 'position' => 3, '_destroy' => 0 }], 'action' => 'create', 'default' => false, 'position' => 1)
      sq.column_name = "cf_int0#{x + 2}"
      sq.save
    end
  end

  def generate_content(survey)
    default_question = { 'question' => Faker::Lorem.sentence(1) }
    additional_question = Hash[survey.survey_questions.where(default: false).map { |x| ["question_#{x.id}", Faker::Lorem.sentence(1)] }]
    default_question_choices = { 'choices' => Hash[survey.survey_questions.where(default: true).first.choices.map { |x| [x[:face_value], Faker::Lorem.sentence(1)] }] }
    additional_question_choices = !additional_question.empty? ? { 'choices' => Hash[survey.survey_questions.where(default: false).first.choices.map { |x| [x[:face_value], Faker::Lorem.sentence(1)] }] } : {}
    default_question_set = default_question.merge(default_question_choices)
    additional_question_set = additional_question.merge(additional_question_choices)
    survey_content = {
        'title_text' => Faker::Lorem.sentence(1),
        'comments_text' => Faker::Lorem.sentence(1),
        'thanks_text' => Faker::Lorem.sentence(1),
        'feedback_response_text' => Faker::Lorem.sentence(1)
      }.merge('default_question' => default_question_set).merge('additional_questions' => additional_question_set)
  end

  # Mark status as outdated if there is any label change in the survey update
  def test_outdated
    create_survey(1, true)
    survey = Account.current.custom_surveys.last
    create_survey_questions(survey)
    payload = generate_content(survey)
    survey.custom_translations.create(translations: payload, language_id: 5, status: SURVEY_STATUS[:translated])

    payload = generate_content(survey)
    survey.custom_translations.create(translations: payload, language_id: 2, status: SURVEY_STATUS[:incomplete])

    previous_survey = survey.as_api_response(:custom_translation).stringify_keys

    # title_text changed here..
    survey.update_attributes(title_text: 'test title')

    Sidekiq::Testing.inline! do
      Admin::CustomTranslations::UpdateSurveyStatus.new.perform(survey_was: previous_survey, survey_id: survey.id)
    end

    cs1 = survey.custom_translations.where(language_id: 5).first
    cs2 = survey.custom_translations.where(language_id: 2).first
    assert_equal cs1.status, SURVEY_STATUS[:outdated]
    assert_equal cs2.status, SURVEY_STATUS[:outdated]
  end

  # status value remains same if there are no changes in the survey update.
  def test_translated
    create_survey(1, true)
    survey = Account.current.custom_surveys.last
    create_survey_questions(survey)
    payload = generate_content(survey)
    survey.custom_translations.create(translations: payload, language_id: 5, status: SURVEY_STATUS[:translated])

    payload = generate_content(survey)
    survey.custom_translations.create(translations: payload, language_id: 2, status: SURVEY_STATUS[:translated])

    previous_survey = survey.as_api_response(:custom_translation).stringify_keys

    Sidekiq::Testing.inline! do
      Admin::CustomTranslations::UpdateSurveyStatus.new.perform(survey_was: previous_survey, survey_id: survey.id)
    end

    cs1 = survey.custom_translations.where(language_id: 5).first
    cs2 = survey.custom_translations.where(language_id: 2).first
    assert_equal cs1.status, SURVEY_STATUS[:translated]
    assert_equal cs2.status, SURVEY_STATUS[:translated]
  end

  # If new questions or choices are added, then change the status to incomplete for all records
  def test_incomplete
    create_survey(1, true)
    survey = Account.current.custom_surveys.last
    create_survey_questions(survey) # creates 3 questions
    survey.survey_questions.first.delete # deletes first question and remains 2 additional questions
    survey.survey_questions.reload

    payload = generate_content(survey)
    survey.custom_translations.create(translations: payload, language_id: 5, status: SURVEY_STATUS[:translated])

    payload = generate_content(survey)
    survey.custom_translations.create(translations: payload, language_id: 2, status: SURVEY_STATUS[:translated])

    previous_survey = survey.as_api_response(:custom_translation).stringify_keys

    create_survey_questions(survey) # creates a question & now there will be 2 additonal questions
    survey.survey_questions.reload

    Sidekiq::Testing.inline! do
      Admin::CustomTranslations::UpdateSurveyStatus.new.perform(survey_was: previous_survey, survey_id: survey.id)
    end

    cs1 = survey.custom_translations.where(language_id: 5).first
    cs2 = survey.custom_translations.where(language_id: 2).first
    assert_equal cs1.status, SURVEY_STATUS[:incomplete]
    assert_equal cs2.status, SURVEY_STATUS[:incomplete]
  end

  # If questions or choices deleted, then change the status based comparison with translations
  def test_incomplete_to_translated
    create_survey(1, true)
    survey = Account.current.custom_surveys.last
    create_survey_questions(survey)
    payload = generate_content(survey)
    survey.custom_translations.create(translations: payload, language_id: 5, status: SURVEY_STATUS[:translated])

    payload = generate_content(survey)
    sample_question = payload['additional_questions'].keys[0]
    payload['additional_questions'].delete(sample_question)
    survey.custom_translations.create(translations: payload, language_id: 2, status: SURVEY_STATUS[:incomplete])

    previous_survey = survey.as_api_response(:custom_translation).stringify_keys

    survey.survey_questions.first.delete # deletes first question and remains 2 additional questions
    survey.survey_questions.reload

    Sidekiq::Testing.inline! do
      Admin::CustomTranslations::UpdateSurveyStatus.new.perform(survey_was: previous_survey, survey_id: survey.id)
    end

    cs1 = survey.custom_translations.where(language_id: 5).first
    cs2 = survey.custom_translations.where(language_id: 2).first
    assert_equal cs1.status, SURVEY_STATUS[:translated]
    assert_equal cs2.status, SURVEY_STATUS[:translated]
  end

  def test_remove_additional_questions
    create_survey(1, true)
    survey = Account.current.custom_surveys.last
    create_survey_questions(survey) # creates 3 questions

    payload = generate_content(survey)
    payload.delete('additional_questions')
    survey.custom_translations.create(translations: payload, language_id: 5, status: SURVEY_STATUS[:translated])

    payload = generate_content(survey)
    payload.delete('additional_questions')
    survey.custom_translations.create(translations: payload, language_id: 2, status: SURVEY_STATUS[:translated])

    previous_survey = survey.as_api_response(:custom_translation).stringify_keys

    Sidekiq::Testing.inline! do
      Admin::CustomTranslations::UpdateSurveyStatus.new.perform(survey_was: previous_survey, survey_id: survey.id)
    end

    cs1 = survey.custom_translations.where(language_id: 5).first
    cs2 = survey.custom_translations.where(language_id: 2).first
    assert_equal cs1.status, SURVEY_STATUS[:incomplete]
    assert_equal cs2.status, SURVEY_STATUS[:incomplete]
  end
end
