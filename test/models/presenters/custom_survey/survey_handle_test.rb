require_relative '../../test_helper'
require Rails.root.join('test', 'api', 'helpers', 'surveys_test_helper.rb')

class SurveyHandleTest < ActiveSupport::TestCase
  include TicketsTestHelper
  include SurveysTestHelper

  SURVEY_SEND_WHILE_VS_TICKET_STATUS = {
    Survey::RESOLVED_NOTIFICATION => EmailNotification::TICKET_RESOLVED,
    Survey::CLOSED_NOTIFICATION => EmailNotification::TICKET_CLOSED
  }.freeze

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
    @ticket = create_ticket
    @@before_all_run = true
  end

  def test_survey_handle_payload
    survey = @account.custom_surveys.first
    create_custom_survey_handle(@ticket, survey.id)
    survey_handle = @account.custom_survey_handles.first
    payload = survey_handle.central_publish_payload.to_json
    payload.must_match_json_expression(survey_handle_pattern(survey_handle))
    assoc_payload = survey_handle.associations_to_publish.to_json

    assoc_payload.must_match_json_expression(
      survey: central_survey_pattern(survey),
      survey_questions: survey_handle_questions_pattern(survey_handle),
      surveyable: surveyable_pattern(survey_handle)
    )
  end

  private

    def create_custom_survey_handle(ticket, survey_id = nil)
      CustomSurvey::SurveyHandle.create_handle_for_notification(ticket, SURVEY_SEND_WHILE_VS_TICKET_STATUS[@account.survey.send_while], survey_id)
    end

    def survey_handle_pattern(handle)
      {
        id: handle.id,
        account_id: handle.account_id,
        surveyable_id: handle.surveyable_id,
        id_token: handle.id_token,
        sent_while: send_while_hash(handle.sent_while),
        response_note_id: handle.response_note_id,
        created_at: handle.created_at,
        updated_at: handle.updated_at,
        survey_id: handle.survey_id,
        survey_result_id: handle.survey_result_id,
        rated: handle.rated,
        preview: handle.preview,
        agent_id: handle.agent_id,
        group_id: handle.group_id
      }
    end
end
