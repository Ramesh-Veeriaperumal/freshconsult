class CustomSurvey::SurveyHandle < ActiveRecord::Base
  self.primary_key = :id
  self.table_name = :survey_handles
  
  concerned_with :associations, :constants

  def self.create_handle(ticket, note, specific_include)
    send_while = specific_include ? CustomSurvey::Survey::SPECIFIC_EMAIL_RESPONSE : CustomSurvey::Survey::ANY_EMAIL_RESPONSE
    create_handle_internal(ticket, send_while, nil, note)
  end
  
  def self.create_handle_for_place_holder(ticket)    
    create_handle_internal(ticket, CustomSurvey::Survey::PLACE_HOLDER)
  end

  def self.create_handle_for_notification(ticket, notification_type,survey_id, preview, portal = false)
    send_while = NOTIFICATION_VS_SEND_WHILE[notification_type]
    create_handle_internal(ticket, send_while, survey_id, note=nil, preview, portal) if send_while
  end

  def self.create_handle_for_portal(ticket, notification_type)
    send_while = NOTIFICATION_VS_SEND_WHILE[notification_type]
    create_handle_internal(ticket, send_while, survey_id=nil, note=nil, preview=false, portal=true, 
                            save=false) if send_while
  end

  def survey_url(ticket, rating)
    Rails.application.routes.url_helpers.support_customer_custom_survey_url(id_token, CustomSurvey::Survey::CUSTOMER_RATINGS[rating],:host => ticket.portal_host, :protocol => ticket.account.url_protocol)
  end
  
  def record_survey_result rating
    old_rating = CustomSurvey::Survey::old_rating rating.to_i

    ActiveRecord::Base.transaction do
      create_survey_result({
        :account_id       => survey.account_id,
        :survey_id        => survey_id,
        :surveyable_id    => surveyable_id,
        :surveyable_type  => surveyable_type,
        :customer_id      => which_customer,
        :agent_id         => which_agent,
        :group_id         => which_group,
        :response_note_id => response_note_id,
        :custom_field     => {
          "#{survey.default_question.name}" => rating
        },
        :rating           => old_rating
      })
      destroy
    end
  end

  def feedback_url(rating)
    survey_result.blank? ? '' : 
      Rails.application.routes.url_helpers.support_custom_survey_feedback_path(survey_result.id, rating)
  end

  def agent_name
    agent.try :name
  end
  
  private

    def which_customer
      User.current.try(:id) || surveyable.requester_id
    end

    def which_agent
      !(agent.blank?) ? agent.id : (response_note ? response_note.user_id : surveyable.responder_id)
    end

    def which_group
      !(group.blank?) ? group.id : surveyable.group_id
    end

    def self.create_handle_internal(ticket, send_while, survey_id = nil, note = nil,
                                      preview = false, portal = false, save = true)
    
      return nil unless (preview or portal or ticket.can_send_survey?(send_while))

      s_handle = ticket.custom_survey_handles.build({
        :id_token   => Digest::MD5.hexdigest("#{Helpdesk::SECRET_1}#{ticket.id}#{Time.now.to_f}").downcase,
        :sent_while => send_while,
        :survey_id  => survey_id || ticket.account.survey.id,
        :account_id => ticket.account_id,
        :preview    => preview,
        :group_id   => ticket.group_id
      })
      s_handle.response_note_id = note.id if note
      s_handle.agent_id = note ? note.user_id : ticket.responder_id
      s_handle.save if save
      s_handle
    end
end