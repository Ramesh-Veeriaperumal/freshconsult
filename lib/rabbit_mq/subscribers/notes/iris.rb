module RabbitMq::Subscribers::Notes::Iris
  
  include RabbitMq::Constants
  
  def mq_iris_note_properties(action)
    iris_model_properties(action, self)
  end
  
  def mq_iris_schema_less_note_properties(action)
   iris_model_properties(action, self.note)
  end

  def mq_iris_subscriber_properties(action)
    object = iris_schema_less_note_model? ? self.note : self
    iris_subscriber_properties(object)
  end

  def mq_iris_valid(action, model)
    iris_valid_model?(model) and iris_note_valid?(action)
  end

  private
  
    def iris_ticket_keys(note)
      IRIS_TICKET_KEYS + [{"custom_fields" => note.notable.non_text_ff_aliases}]
    end
  
    def iris_subscriber_properties(note)
      # Calling the method separately because if exception occures in BusinessCalendar.execute
      # then subscriber properties is returning null without the model changes
      action_in_bhrs_flag = iris_action_in_bhrs?(note) 
      {
        :action_in_bhrs => action_in_bhrs_flag,
        :action_time_in_bhrs => note.response_time_by_bhrs,
        :action_time_in_chrs => note.response_time_in_seconds
      }
    end
    
    def iris_model_properties(action, note)
      note_info     = note.to_rmq_json(IRIS_NOTE_KEYS, action)
      ticket_action = destroy_action?(action) ? CRUD[1] : action
      ticket_info   = note.notable.to_rmq_json(iris_ticket_keys(note), ticket_action)
      note_info.merge!({"ticket" => ticket_info})
    end
    
    def iris_valid_model?(model)
      model == "note"
    end

    def iris_note_valid?(action)
      (create_action?(action) or destroy_action?(action)) and human_note_for_ticket?
    end
    
    def iris_action_in_bhrs?(note) 
      BusinessCalendar.execute(note.notable) do
        action_occured_in_bhrs?(note.created_at, note.notable.group)
      end
    end
  
end