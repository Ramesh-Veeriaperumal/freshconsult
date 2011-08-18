class SurveyHandle < ActiveRecord::Base
  include ActionController::UrlWriter
  
  NOTIFICATION_VS_SEND_WHILE = {
    EmailNotification::TICKET_RESOLVED => Survey::RESOLVED_NOTIFICATION
  }
  
  belongs_to :account
  belongs_to :surveyable, :polymorphic => true
  belongs_to :response_note, :class_name => 'Helpdesk::Note'
  
  def self.create_handle(ticket, note)
    create_handle_internal(ticket, Survey::ANY_EMAIL_RESPONSE, note)
  end
  
  def self.create_handle_for_notification(ticket, notification_type)
    send_while = NOTIFICATION_VS_SEND_WHILE[notification_type]
    create_handle_internal(ticket, send_while) if send_while
  end
  
  def survey_url(ticket, rating)
    support_customer_survey_url(id_token, SurveyPoint::CUSTOMER_RATINGS[rating], 
      :host => ticket.portal_host)
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
      s_handle.response_note_id = note.id if note
      s_handle.save

      s_handle
    end
end
