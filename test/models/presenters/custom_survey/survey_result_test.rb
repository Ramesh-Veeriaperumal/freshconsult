require_relative '../../test_helper'
require Rails.root.join('test', 'api', 'helpers', 'surveys_test_helper.rb')

class SurveyResultTest < ActiveSupport::TestCase
  include ::CustomSurvey::SurveyResult::PublisherMethods
  include TicketsTestHelper
  include SurveysTestHelper

  @@ticket = nil

  def setup
    super
    Sidekiq::Worker.clear_all
    before_all
    @@ticket = @ticket = @@ticket || create_ticket
  end

  def before_all
    create_survey(1, true)
    CentralPublishWorker::SurveyWorker.jobs.clear
    @@before_all_run = true
  end

  def test_survey_result_payload
    survey = @account.custom_surveys.last
    result = create_survey_result(@ticket, 103, nil, survey.id)
    payload = result.central_publish_payload.to_json
    payload.must_match_json_expression(survey_result_pattern(result))
  end

  def test_survey_result_assoc_payload
    survey = @account.custom_surveys.last
    result = create_survey_result(@ticket, 103, nil, survey.id)
    payload = result.associations_to_publish.to_json
    payload.must_match_json_expression(
      survey: central_survey_pattern(survey),
      surveyable: surveyable_pattern(result)
    )
  end

  private

    def survey_result_pattern(result)
      {
        id: result.id,
        account_id: result.account_id,
        survey_id: result.survey_id,
        surveyable_id: result.surveyable_id,
        customer_id: result.customer_id,
        agent_id: result.agent_id,
        response_note_id: result.response_note_id,
        rating: result.old_rating(result.rating),
        group_id: result.group_id,
        custom_fields: survey_result_data_payload(result),
        created_at: result.created_at.try(:utc).try(:iso8601),
        updated_at: result.updated_at.try(:utc).try(:iso8601)
      }
    end

    def survey_result_data_payload(result)
      survey_result_data = result.survey_result_data.reload
      survey_questions = result.survey_result_data.custom_fields_cache

      survey_questions.map do |question|
        face_value = survey_result_data.safe_send(question.column_name)
        result = { question_id: question.id, question: question.name }

        if face_value.present?
          choices = question.choices
          choice = choices.find { |c| c[:face_value] == face_value }[:name]
          result.merge!(choice: choice, choice_value: face_value, rating: old_rating(face_value))
        else
          result.merge!(choice: nil, choice_value: nil, rating: nil)
        end
        result
      end.compact
    end
end
