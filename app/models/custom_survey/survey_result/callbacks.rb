class CustomSurvey::SurveyResult < ActiveRecord::Base  

  before_create :build_survey_remark_and_feedback_note
  after_create  :update_observer_events, :update_ticket_rating, :if => :ticket_survey?
  after_commit  :filter_observer_events, on: :create, :if => :user_present?

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

end