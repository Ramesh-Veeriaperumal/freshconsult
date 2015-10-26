module RabbitMq::Subscribers::Notes::Reports
  
  include RabbitMq::Constants
  
  VALID_MODELS      = ["note", "schema_less_note"]
  RESP_TIME_COLUMNS = ["int_nc02", "int_nc03" ]
  
  def mq_reports_note_properties(action)
    reports_model_properties(action, self)
  end
  
  def mq_reports_schema_less_note_properties(action)
   reports_model_properties(action, self.note)
  end

  def mq_reports_subscriber_properties(action)
    object = schema_less_note_model? ? self.note : self
    reports_subscriber_properties(object)
  end

  def mq_reports_valid(action, model)
    account.reports_enabled? && valid_model?(model) && send("#{model}_valid?", action)
  end

  private
  
    def report_ticket_keys(note)
      REPORTS_TICKET_KEYS + [{"custom_fields" => note.notable.non_text_ff_aliases}]
    end
  
    def reports_subscriber_properties(note)
      # Calling the method separately because if exception occures in BusinessCalendar.execute
      # then subscriber properties is returning null without the model changes
      action_in_bhrs_flag = action_in_bhrs?(note) 
      {
        :action_in_bhrs => action_in_bhrs_flag,
        :action_time_in_bhrs => note.response_time_by_bhrs,
        :action_time_in_chrs => note.response_time_in_seconds,
        :valid_key           => Helpdesk::Activity::MIGRATION_KEYS.first
      }
    end
    
    def reports_model_properties(action, note)
      note_info     = note.to_rmq_json(REPORTS_NOTE_KEYS, action)
      ticket_action = destroy_action?(action) ? CRUD[1] : action
      ticket_info   = note.notable.to_rmq_json(report_ticket_keys(note), ticket_action)
      note_info.merge!({"ticket" => ticket_info})
    end
    
    def valid_model?(model)
      VALID_MODELS.include?(model)
    end
    
    def schema_less_note_model?
      self.is_a?(Helpdesk::SchemaLessNote)
    end
    
    def schema_less_note_valid?(action)
      (self.previous_changes.keys & RESP_TIME_COLUMNS).any?
    end
    
    def note_valid?(action)
      return false if notable.archive || !human_note_for_ticket? || feedback? || (user.customer? && replied_by_third_party?)
      non_archive_destroy?(action) || (create_action?(action) && selected_note_kinds)
    end
    
    # When a ticket is moved to archive as a part of the callback, note destroy happens.
    # But this should not trigger an update to RMQ. 
    def non_archive_destroy?(action)
      destroy_action?(action) && !notable.archive
    end

    def selected_note_kinds
      (customer_reply? || private_note? || fwd_email? || reply_to_forward? || consecutive_agent_response?)
    end
    
    def customer_reply?
      (incoming && user.customer?)
    end
    
    def consecutive_agent_response?
      return false if agent_first_response? 
      cust_resp = notable.notes.visible.customer_responses.
          created_between(notable.ticket_states.agent_responded_at,created_at).first(
          :select => "helpdesk_notes.id,helpdesk_notes.created_at", 
          :order => "helpdesk_notes.created_at ASC")
      cust_resp.blank?
    end
    
    def agent_first_response?
      # This check is to identify that whether the current note is a first response or not
      # we set the "first_resp_time_by_bhrs" at the resque. 
      # So if the first_resp_time_by_bhrs is nil the current note is consider to be a first response
      # For the consecutive response, the response time will be populated.
      # This might have an issue in case where the resque is slower. There is no way to handle the case currently
      notable.ticket_states.first_resp_time_by_bhrs.nil?
    end
    
    def action_in_bhrs?(note) 
      BusinessCalendar.execute(note.notable) do
        action_occured_in_bhrs?(note.created_at, note.notable.group)
      end
    end
  
end