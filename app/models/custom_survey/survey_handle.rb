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

  def self.create_handle_for_notification(ticket, notification_type,survey_id)
    send_while = NOTIFICATION_VS_SEND_WHILE[notification_type]
    create_handle_internal(ticket, send_while, survey_id, note=nil) if send_while
  end

  def self.create_handle_for_portal(ticket, notification_type)
    send_while = NOTIFICATION_VS_SEND_WHILE[notification_type]
    create_handle_internal(ticket, send_while, survey_id=nil, note=nil, preview=false, portal=true) if send_while
  end

  def self.create_handle_for_preview(survey_id, send_while)
    create_handle_internal(ticket=nil, send_while, survey_id, note=nil, preview=true)
  end
  
  def record_survey_result rating
    old_rating = CustomSurvey::Survey::old_rating rating.to_i

    ActiveRecord::Base.transaction do
      create_survey_result({
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
                                      preview = false, portal = false)
    
      return nil unless (preview or portal or ticket.can_send_survey?(send_while))

      s_handle = self.new({
        :id_token   => Digest::MD5.hexdigest("#{Helpdesk::SECRET_1}_#{survey_id}_#{ticket.try(:id)}_#{Time.now.to_f}").downcase,
        :sent_while => send_while,
        :survey_id  => survey_id || Account.current.survey.id,
        :preview    => preview
      })
      if note.present?
        s_handle.response_note_id = note.id
        s_handle.agent_id = note.user_id
      end
      if ticket.present?
        s_handle.surveyable = ticket 
        s_handle.group_id = ticket.group_id
        s_handle.agent_id ||= ticket.responder_id
      end
      s_handle.save
      s_handle
    end
end