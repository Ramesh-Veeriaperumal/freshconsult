class CustomSurvey::SurveyResult < ActiveRecord::Base  

  before_validation :backup_custom_field_changes, on: :update
  before_create :build_survey_remark_and_feedback_note
  after_create  :update_observer_events, :update_ticket_rating, :if => :ticket_survey?
  after_commit  :filter_observer_events, on: :create, :if => :user_present?
  after_commit :backup_custom_field_changes, on: :update

  private

  def build_survey_remark_and_feedback_note
    feedback = surveyable.notes.build({
      :user_id  => customer_id,
      :note_body_attributes => {
        :body      => '', 
        :body_html => '<div></div>'
      },
      :source   => Helpdesk::Note::SOURCE_KEYS_BY_TOKEN["feedback"],
      :incoming => true,
      :private  => false
    })
    feedback.build_note_and_sanitize
    remark = build_survey_remark
    remark.feedback = feedback
  end

  def update_ticket_rating
    surveyable.st_survey_rating = rating
    surveyable.survey_rating_updated_at = created_at
    surveyable.save
  end

  def update_observer_events
    @model_changes = { :customer_feedback => rating }
  end   

  def ticket_survey?
    surveyable.is_a?(Helpdesk::Ticket)
  end

  def backup_custom_field_changes
    # No custom fields for default survey.
    return if self.survey.default? || ( @model_changes.present? && @model_changes[:custom_fields].nil? )
    @model_changes ||= {}
    (@model_changes[:custom_fields] ||= []) << survey_result_data_payload
  end

end