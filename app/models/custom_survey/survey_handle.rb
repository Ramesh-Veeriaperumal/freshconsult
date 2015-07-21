class CustomSurvey::SurveyHandle < ActiveRecord::Base
  self.primary_key = :id
  self.table_name = :survey_handles
  
  concerned_with :associations, :constants

  def self.create_handle(ticket, note, specific_include)
    create_handle_internal(ticket, 
      (specific_include) ? CustomSurvey::Survey::SPECIFIC_EMAIL_RESPONSE : CustomSurvey::Survey::ANY_EMAIL_RESPONSE , 
      nil,note)
  end
  
  def self.create_handle_for_place_holder(ticket)    
    create_handle_internal(ticket, CustomSurvey::Survey::PLACE_HOLDER)
  end

  def self.create_handle_for_notification(ticket, notification_type,survey_id, preview, portal = false)
    send_while = NOTIFICATION_VS_SEND_WHILE[notification_type]
    create_handle_internal(ticket, send_while, survey_id, note=nil, preview, portal) if send_while
  end

  def survey_url(ticket, rating)
    Rails.application.routes.url_helpers.support_customer_custom_survey_url(id_token, CustomSurvey::Survey::CUSTOMER_RATINGS[rating],:host => ticket.portal_host)
  end
  
  def create_survey_result rating
    clear_survey_result if survey_result
    
    old_rating = CustomSurvey::Survey::old_rating rating.to_i

    build_survey_result({
      :account_id => survey.account_id,
      :survey_id => survey_id,
      :surveyable_id => surveyable_id,
      :surveyable_type => surveyable_type,
      :customer_id => surveyable.requester_id,
      :agent_id => which_agent,
      :group_id => which_group,
      :response_note_id => response_note_id,
      :custom_field => {"#{survey.default_question.name}" => rating},
      :rating => old_rating
    })
    
    self.rated = true
    
    save
  end

  def feedback_url(rating)
    url = survey_result.blank? ? '' : Rails.application.routes.url_helpers.support_custom_survey_feedback_path(survey_result.id, rating)
    url
  end

  def agent_name
      account.users.find(agent_id).name
  end
  
  private

    def which_agent
          !(agent.blank?) ? agent.id : (response_note ? response_note.user_id : surveyable.responder_id)
    end

    def which_group
          !(group.blank?) ? group.id : surveyable.group_id
    end

    def self.create_handle_internal(ticket, send_while, survey_id = nil, note = nil,preview = false, portal = false)
      if(!preview and !portal)
        return nil unless ticket.can_send_survey?(send_while)
      end
      s_handle = ticket.custom_survey_handles.build({
        :id_token => Digest::MD5.hexdigest(Helpdesk::SECRET_1 + ticket.id.to_s + 
          Time.now.to_f.to_s).downcase,
        :sent_while => send_while
      })
      survey_id ||= ticket.account.survey.id
      s_handle.survey_id = survey_id
      s_handle.account_id = ticket.account_id
      s_handle.response_note_id = note.id if note
      s_handle.preview = preview
      s_handle.agent_id = note ? note.user_id : ticket.responder_id
      s_handle.group_id = ticket.group_id
      s_handle.save
      s_handle
    end
    
    def clear_survey_result
      survey_result.destroy
    end
    
end
