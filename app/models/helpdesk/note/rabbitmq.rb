class Helpdesk::Note < ActiveRecord::Base
  
  
  def manual_publish_to_rmq(action, key, options = {})
    # TODO currently the manual publish is specific to reports
    # But need to reorg this method such that it pushes only msg to rmq
    # for all the subscribers(reports, activities, search etc)
    manual_publish_to_xchg("note", (reports_rmq_msg(action, options)).to_json, key)
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
      "account_id"  =>  account_id
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
      "archive"     =>   notable.archive || false
    }
  end
  
  # Used for publishing the message manually to rabbitmq
  def reports_rmq_msg(action, options)
    { 
      "object"                =>  "note",
      "action"                =>  action,
      "action_epoch"          =>  Time.zone.now.to_f,
      "note_properties"       =>  mq_reports_note_properties(action),
      "subscriber_properties" =>  {"reports" => mq_reports_subscriber_properties(action).merge(options) }    
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