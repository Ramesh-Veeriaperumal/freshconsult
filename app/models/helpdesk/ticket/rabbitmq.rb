class Helpdesk::Ticket < ActiveRecord::Base

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
      "visible"          =>   spam || deleted || (parent_ticket ? 0 : 1),
      "responder_name"   =>   responder.nil? ? "" : responder.name,
      "subject"          =>   subject,
      "description"      =>   description[0..50],
      "requester_name"   =>   requester.name,
      "due_by"           =>   due_by.to_i,
      "is_escalated"     =>   isescalated,
      "fr_escalated"     =>   fr_escalated,      
      "created_at"       =>   created_at.to_i,
      "tag_names"        =>   tags.map(&:name)
    }
  end

  def ticket_schemaless_hash 
    @rmq_ticket_schemaless_hash ||= {
      "sla_policy_id"   => schema_less_ticket.sla_policy_id,
      "product_id"      => schema_less_ticket.product_id
    } 
  end

  def ticket_custom_field_hash
    {
      "custom_fields" => custom_field.stringify_keys
    }    
  end

  def ticket_states_hash
    @rmq_ticket_states_hash ||= {
      "resolved_at"                 =>  resolved_at.to_i,
      "time_to_resolution_in_bhrs"  =>  ticket_states.resolution_time_by_bhrs,
      "time_to_resolution_in_chrs"  =>  (resolved_at ? (resolved_at - created_at) : nil ),
      "fcr_violation"               =>  (resolved_at ? ticket_states.inbound_count > 1 : nil),
      "first_response_by_bhrs"      =>  ticket_states.first_resp_time_by_bhrs,
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