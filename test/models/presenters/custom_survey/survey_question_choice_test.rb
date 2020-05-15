require_relative '../../test_helper'
require Rails.root.join('test', 'api', 'helpers', 'surveys_test_helper.rb')

class SurveyQuestionChoiceTest < ActiveSupport::TestCase
  include SurveysTestHelper

  def setup
    super
    Sidekiq::Worker.clear_all
    before_all
  end

  @@before_all_run = false

  def before_all
    return if @@before_all_run
    create_survey(1, true)
    CentralPublishWorker::SurveyWorker.jobs.clear
    @@before_all_run = true
  end

  def test_survey_question_choice_payload
    survey = @account.custom_surveys.last
    question = survey.survey_questions.last
    choices = CustomSurvey::SurveyQuestionChoice.where(survey_question_id: question.id)

    choices.each do |choice|
      payload = choice.central_publish_payload.to_json
      payload.must_match_json_expression(survey_question_choice_pattern(choice))
    end
  end

  private

    def survey_question_choice_pattern(choice)
      {
        id: choice.id,
        account_id: choice.account_id,
        survey_question_id: choice.survey_question_id,
        value: choice.value,
        face_value: choice.face_value,
        position: choice.position,
        created_at: choice.created_at,
        updated_at: choice.updated_at
      }
    end
end
