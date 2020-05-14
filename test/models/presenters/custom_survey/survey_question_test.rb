require_relative '../../test_helper'
require Rails.root.join('test', 'api', 'helpers', 'surveys_test_helper.rb')

class SurveyQuestionTest < ActiveSupport::TestCase
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

  def test_survey_question_payload
    survey = @account.custom_surveys.last

    survey.survey_questions.each do |question|
      payload = question.central_publish_payload.to_json
      payload.must_match_json_expression(survey_question_pattern(question))
      assoc_payload = question.associations_to_publish.to_json
      assoc_payload.must_match_json_expression(survey: central_survey_pattern(survey))
    end
  end

  private

    def survey_question_pattern(question)
      {
        id: question.id,
        account_id: question.account_id,
        survey_id: question.survey_id,
        name: question.name,
        field_type: question.field_type,
        position: question.position,
        deleted: question.deleted,
        label: question.label,
        column_name: question.column_name,
        default: question.default,
        created_at: question.created_at,
        updated_at: question.updated_at
      }
    end
end
