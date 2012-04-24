class SurveyResult < ActiveRecord::Base
  has_one :survey_remark, :dependent => :destroy
  belongs_to :surveyable, :polymorphic => true
  
  def add_feedback(feedback)
    note = surveyable.notes.build({
      :user_id => customer_id,
      :body => feedback,
      :source => Helpdesk::Note::SOURCE_KEYS_BY_TOKEN["feedback"],
      :incoming => true,
      :private => false
    })
    
    note.account_id = account_id
    note.save
    
    create_survey_remark({
      :note_id => note.id
    })
    
    add_support_score
  end
  
  def happy?
    (rating == Survey::HAPPY)
  end

  def unhappy?
    (rating == Survey::UNHAPPY)
  end
  
  private
    def add_support_score
      SupportScore.happy_customer(surveyable) if happy?
      SupportScore.unhappy_customer(surveyable) if unhappy?
    end
end
