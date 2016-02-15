class Helpdesk::Ticket < ActiveRecord::Base
  
  
  def manual_publish_to_rmq(action, key, options = {})
    # TODO currently the manual publish is specific to reports
    # But need to reorg this method such that it pushes only msg to rmq
    # for all the subscribers(reports, activities, search etc)
    manual_publish_to_xchg("ticket", (reports_rmq_msg(action, options)).to_json, key)
  end

  def to_rmq_json(keys, action)
    return ticket_identifiers if destroy_action?(action)
    @rmq_ticket_details ||= [ticket_identifiers, ticket_basic_properties, ticket_schemaless_hash, 
                                ticket_custom_field_hash, ticket_states_hash].reduce(&:merge)
    return_specific_keys(@rmq_ticket_details, keys)
  end

  private

  def ticket_identifiers
    @rmq_ticket_identifiers ||= {
      "id"          =>  id,
      "display_id"  =>  display_id,      
      "account_id"  =>  account_id
     }
  end  
  
  def ticket_basic_properties
    @rmq_ticket_basic_properties ||= {
      "responder_id"     =>   responder_id,
      "agent_id"         =>   responder_id,
      "group_id"         =>   group_id,
      "company_id"       =>   company_id,
      "status"           =>   status,
      "priority"         =>   priority,
      "source"           =>   source,
      "requester_id"     =>   requester_id,
      "ticket_type"      =>   ticket_type,
      "visible"          =>   visibility_state,
      "responder_name"   =>   responder.nil? ? "" : responder.name,
      "subject"          =>   subject,
      "requester_name"   =>   requester.name,
      "due_by"           =>   due_by.to_i,
      "is_escalated"     =>   isescalated,
      "fr_escalated"     =>   fr_escalated,      
      "created_at"       =>   created_at.to_i,
      "archive"          =>   archive || false
    }
  end
  
  def ticket_schemaless_hash 
    @rmq_ticket_schemaless_hash ||= {
      "sla_policy_id"   =>  schema_less_ticket.sla_policy_id,
      "product_id"       => schema_less_ticket.product_id
    }.merge(schema_less_ticket.reports_hash)
  end

  def ticket_custom_field_hash
    # Sending only non text custom fields in the JSON (All except the single line and paragraph fields)
    {
      "custom_fields" => custom_field.select { |k,v| non_text_ff_aliases.include?(k.to_s) }.stringify_keys
    }    
  end

  def ticket_states_hash
    @rmq_ticket_states_hash ||= {
      "resolved_at"                 =>  resolved_at.to_i,
      "time_to_resolution_in_bhrs"  =>  ticket_states.resolution_time_by_bhrs,
      "time_to_resolution_in_chrs"  =>  (resolved_at ? (resolved_at - created_at) : nil ),
      "first_response_by_bhrs"      =>  ticket_states.first_resp_time_by_bhrs,
      "inbound_count"               =>  ticket_states.inbound_count
    }
  end

  def reports_rmq_msg(action, options)
    { 
        "object"                =>  "ticket",
        "action"                =>  action,
        "action_epoch"          =>  Time.zone.now.to_f,
        "ticket_properties"     =>  mq_reports_ticket_properties(action),
        "subscriber_properties" =>  { "reports" => mq_reports_subscriber_properties(action).merge(options)  }     
    }
  end

  def visibility_state
    # We have a priority in deciding the visibility state. Deleted is the first check we make, 
    # then spam and parent ticket
    case 
    when deleted
      VISIBILITY_MAPPING[:deleted]
    when spam
      VISIBILITY_MAPPING[:spam]
    when parent_ticket
      VISIBILITY_MAPPING[:merged_ticket]
    else
      VISIBILITY_MAPPING[:active]
    end
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