class SurveyHandle < ActiveRecord::Base
	
  belongs_to_account
  	
  include ActionController::UrlWriter
  
  NOTIFICATION_VS_SEND_WHILE = {
    EmailNotification::TICKET_RESOLVED => Survey::RESOLVED_NOTIFICATION
  }
  
  belongs_to :survey
  belongs_to :surveyable, :polymorphic => true
  belongs_to :response_note, :class_name => 'Helpdesk::Note'
  belongs_to :survey_result
  
  def self.create_handle(ticket, note)  	
    create_handle_internal(ticket, Survey::ANY_EMAIL_RESPONSE, note)
  end
  
  def self.create_handle_for_notification(ticket, notification_type)
    send_while = NOTIFICATION_VS_SEND_WHILE[notification_type]
    create_handle_internal(ticket, send_while) if send_while
  end
  
  def survey_url(ticket, rating)
    support_customer_survey_url(id_token, Survey::CUSTOMER_RATINGS[rating], 
      :host => ticket.portal_host)
  end
  
  def create_survey_result(rating)
    clear_survey_result if survey_result
    
    build_survey_result({
      :account_id => survey.account_id,
      :survey_id => survey_id,
      :surveyable_id => surveyable_id,
      :surveyable_type => surveyable_type,
      :customer_id => surveyable.requester_id,
      :agent_id => surveyable.responder_id,
      :response_note_id => response_note_id,
      :rating => rating
    })
    
    #Chose not to add support score at this point. Rather will do that when he gives
    #feedback (natural next step..)
    
    save
  end
  
  private
    def self.create_handle_internal(ticket, send_while, note = nil)      
      return nil unless ticket.account.survey.can_send?(ticket, send_while)
      
      s_handle = ticket.survey_handles.build({
        :id_token => Digest::MD5.hexdigest(Helpdesk::SECRET_1 + ticket.id.to_s + 
          Time.now.to_f.to_s).downcase,
        :sent_while => send_while
      })
      s_handle.account_id = ticket.account_id
      s_handle.survey_id = ticket.account.survey.id
      s_handle.response_note_id = note.id if note
      s_handle.save

      s_handle
    end
    
    def clear_survey_result
      survey_result.destroy
    end
    
end
