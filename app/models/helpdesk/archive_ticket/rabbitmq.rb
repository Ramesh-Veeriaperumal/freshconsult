# encoding: utf-8
require 'digest/md5'

class Helpdesk::ArchiveTicket < ActiveRecord::Base
  
  include RabbitMq::Publisher
  
  def manual_publish_to_rmq(action, key, options = {})
    # TODO currently the manual publish is specific to reports
    # But need to reorg this method such that it pushes only msg to rmq
    # for all the subscribers(reports, activities, search etc)
    manual_publish_to_xchg("archive_ticket", (reports_rmq_msg(action, options)).to_json, key)
  end

  def to_rmq_json(keys, action)
    @rmq_archive_ticket_details ||= [archive_ticket_identifiers, archive_ticket_basic_properties, archive_ticket_schemaless_hash, 
                                archive_ticket_custom_field_hash, archive_ticket_states_hash].reduce(&:merge)
    return_specific_keys(@rmq_archive_ticket_details, keys)
  end

  private

  def archive_ticket_identifiers
    @rmq_archive_ticket_identifiers ||= {
      "id"          =>  id,
      "display_id"  =>  display_id,      
      "account_id"  =>  account_id
     }
  end  
  
  def archive_ticket_basic_properties
    @rmq_archive_ticket_basic_properties ||= {
      "responder_id"     =>   responder_id,
      "agent_id"         =>   responder_id,
      "group_id"         =>   group_id,
      "company_id"       =>   owner_id,
      "status"           =>   status,
      "priority"         =>   priority,
      "source"           =>   source,
      "product_id"       =>   product_id,
      "requester_id"     =>   requester_id,
      "ticket_type"      =>   ticket_type,
      "visible"          =>   !merge_ticket ,
      "responder_name"   =>   responder.nil? ? "" : responder.name,
      "subject"          =>   subject,
      "requester_name"   =>   requester.name,
      "due_by"           =>   due_by.to_i,
      "is_escalated"     =>   isescalated,
      "fr_escalated"     =>   fr_escalated,      
      "created_at"       =>   created_at.to_i,
      "archive"          =>   true 
    }
  end
  
  def archive_ticket_schemaless_hash 
    @rmq_archive_ticket_schemaless_hash ||= {
      "sla_policy_id"   =>  sla_policy_id
    }.merge(reports_hash)
  end

  def archive_ticket_custom_field_hash
    {
      "custom_fields" => custom_field.stringify_keys
    }    
  end

  def archive_ticket_states_hash
    @rmq_archive_ticket_states_hash ||= {
      "resolved_at"                 =>  resolved_at.to_i,
      "time_to_resolution_in_bhrs"  =>  resolution_time_by_bhrs,
      "time_to_resolution_in_chrs"  =>  (resolved_at ? (resolved_at - created_at) : nil ),
      "first_response_by_bhrs"      =>  first_resp_time_by_bhrs,
      "inbound_count"               =>  inbound_count
    }
  end

  def reports_rmq_msg(action, options)
    { 
      "object"                       =>  "archive_ticket",
      "action"                       =>  action,
      "action_epoch"                 =>  Time.zone.now.to_i,
      "archive_ticket_properties"    => mq_reports_archive_ticket_properties(action),
      "subscriber_properties"        =>  { "reports" => mq_reports_subscriber_properties(action).merge(options)  }     
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