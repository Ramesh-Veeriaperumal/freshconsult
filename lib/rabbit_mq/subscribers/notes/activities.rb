module RabbitMq::Subscribers::Notes::Activities
  
  include RabbitMq::Constants
  include ActivityConstants

  def mq_activities_note_properties(action)
    self.to_rmq_json(activities_note_keys,action) 
  end

  def mq_activities_subscriber_properties(action)
    note_activities_subscriber_properties(action, self)
  end

  def note_activities_subscriber_properties(action, note)
    { :object_id => note.notable.display_id, :content => note_properties(action, note) }
  end

  def mq_activities_valid(action, model)
    Account.current.features?(:activity_revamp) and act_note_valid_model?(model) and act_note_valid?(action)
  end
  
  private

  def act_note_valid_model?(model)
    model == "note"
  end

  def act_note_valid?(action)
    (create_action?(action) or destroy_action?(action)) and human_note_for_ticket?
  end

  def activities_note_keys
    ACTIVITIES_NOTE_KEYS
  end

  def valid_changes?
    self.previous_changes.any?
  end

  def note_properties(action, note)
    {
      :note => {
        :id => note.id
      }
    }
  end

end
