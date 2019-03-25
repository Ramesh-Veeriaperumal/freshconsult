require_relative '../test_helper'
require Rails.root.join('test', 'api', 'helpers', 'surveys_test_helper.rb')

class SurveyResultTest < ActiveSupport::TestCase
  include TicketsTestHelper
  include SurveysTestHelper

  def setup
    super
    Sidekiq::Worker.clear_all
    before_all
  end

  @@before_all_run = false

  def before_all
    return if @@before_all_run
    @account.launch(:surveys_central_publish)
    create_survey(1, true)
    CentralPublishWorker::SurveyWorker.jobs.clear
    @ticket = create_ticket
    @@before_all_run = true
  end

  def test_survey_result_payload
    survey = @account.surveys.first
    result = create_default_survey_result(@ticket, 1, nil, survey.id)
    payload = result.central_publish_payload.to_json
    payload.must_match_json_expression(survey_result_pattern(result))

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
        rating: result.rating,
        group_id: result.group_id,
        custom_fields: survey_result_data_payload(result),
        created_at: result.created_at.try(:utc).try(:iso8601),
        updated_at: result.updated_at.try(:utc).try(:iso8601)
      }
    end
end
