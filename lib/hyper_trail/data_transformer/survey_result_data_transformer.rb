class HyperTrail::DataTransformer::SurveyResultDataTransformer < HyperTrail::DataTransformer::ActivityDataTransformer
  ACTIVITY_TYPE = 'survey'.freeze
  UNIQUE_ID = 'id'.freeze
  PRELOAD_OPTIONS = [:surveyable, survey_remark: { feedback: { note_body: {} } }, survey: { survey_questions: :custom_field_choices }, survey_result_data: { custom_form: {} }].freeze

  def activity_type
    ACTIVITY_TYPE
  end

  def unique_id
    UNIQUE_ID
  end

  def transform
    loaded_survey_results = load_objects_from_db
    loaded_survey_results.each do |survey_result|
      survey_result_object = data_map[survey_result.id]
      surveyable = survey_result.surveyable
      next if survey_result_object.blank? || surveyable.is_a?(Helpdesk::ArchiveTicket) || !surveyable.visible? || !current_user.has_ticket_permission?(surveyable)

      survey_result_object.valid = true
      activity = survey_result_object.activity
      activity[:activity][:context] = fetch_decorated_properties_for_object(survey_result)
      activity[:activity][:timestamp] = survey_result.created_at.try(:utc)
      survey_result_object.activity = activity
    end
  end

  private

    def load_objects_from_db
      current_account.custom_survey_results
                     .where(id: object_ids)
                     .preload(PRELOAD_OPTIONS)
    end

    def fetch_decorated_properties_for_object(survey_result)
      ret_hash = {
        id: survey_result.id,
        survey_id: survey_result.survey_id,
        agent_id: survey_result.agent_id,
        group_id: survey_result.group_id,
        rating: survey_result.custom_ratings,
        created_at: survey_result.created_at.try(:utc)
      }
      ret_hash[:associated_data] = {
        comment: survey_result.survey_remark.feedback.body,
        ticket_subject: survey_result.surveyable.subject
      }
      ret_hash
    end
end
