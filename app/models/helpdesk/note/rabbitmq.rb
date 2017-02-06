class Helpdesk::Note < ActiveRecord::Base
  
  ACTOR_TYPE = {
    :agent   => 1,
    :contact => 2
  }

  def manual_publish_to_rmq(action, key, options = {})
    # Manual publish for note model
    # Currently handled for reports and activities subscribers
    # Need to Append RMQ_GENERIC_NOTE_KEY to enable for new subscribers
    uuid = generate_uuid
    manual_publish_to_xchg(uuid, "note", subscriber_manual_publish("note", action, options, uuid), key)
  end

  def delayed_manual_publish_to_rmq(action, key, options = {})
    # Manual publish for note model
    # Currently handled for reports and activities subscribers
    # Need to Append RMQ_GENERIC_NOTE_KEY to enable for new subscribers
    uuid = generate_uuid
    manual_publish_to_xchg(uuid, "note", subscriber_manual_publish("note", action, options, uuid), key, true)
  end

  def to_rmq_json(keys, action)
    return note_identifiers if destroy_action?(action)
    @rmq_note_details ||= [note_identifiers, note_basic_properties].reduce(&:merge)
    return_specific_keys(@rmq_note_details, keys)
  end

  private

  def note_identifiers
    @rmq_note_identifiers ||= {
      "id"          =>  id,
      "account_id"  =>  account_id,
      "created_at"  =>  created_at.to_i
     }
  end  

  def note_basic_properties
    @rmq_note_basic_properties ||= {
      "source"      =>   source,
      "category"    =>   schema_less_note.category,
      "user_id"     =>   user_id,
      "agent"       =>   (human_note_for_ticket? && notable.agent_performed?(user)),
      "private"     =>   private,
      "incoming"    =>   incoming,
      "deleted"     =>   deleted,
      "created_at"  =>   created_at.to_i,
      "kind"        =>   kind,
      "ticket_id"   =>   (notable_type == "Helpdesk::Ticket") ? notable.display_id : "",
      # @ARCHIVE TODO Currently setting archive as false. 
      # Will change it once "archiving tickets" feature is rolled out.
      "archive"     =>   notable.archive || false,
      "actor_type"  =>   (user.agent? ? ACTOR_TYPE[:agent] : ACTOR_TYPE[:contact])
    }
  end
  
  def return_specific_keys(hash, keys)
    new_hash = {}
    keys.each do |key|
      if key.class.name == "String"
        new_hash[key] = hash[key]
      elsif key.class.name == "Hash"
        current_key = key.keys.first
        if !hash[current_key].nil?
          new_hash[current_key] = return_specific_keys(hash[current_key], key[current_key])
        end
      end
    end
    new_hash
  end
end