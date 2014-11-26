module Mobile::Actions::User

	include Mobile::Actions::Push_Notifier

	def to_mob_json_search
    options = { 
      :methods => [ :avatar_url, :is_agent, :is_customer,  :is_client_manager, :company_name,:user_time_zone],
      :only => [ :id, :name, :email, :mobile, :phone, :job_title, :twitter_id, :fb_profile_id ]
    }
    as_json(options,true).to_json
  end
  
	def to_mob_json
    options = { 
      :methods => [ :original_avatar, :medium_avatar, :avatar_url, :is_agent, 
      							:is_customer, :recent_tickets, :is_client_manager, :company_name,
                    :can_reply_ticket, :can_edit_ticket_properties, :can_delete_ticket, :user_time_zone,
                    :can_view_time_entries, :can_edit_time_entries, :agent_signature ],
                    
      :only => [ :id, :name, :email, :mobile, :phone, :job_title, :twitter_id, :fb_profile_id ]
    }
    as_json(options,true).to_json
  end

  def original_avatar
    avatar_url(:original)
  end

  def medium_avatar
    avatar_url(:medium)
  end

  def avatar_url(profile_size = :thumb)
    avatar.expiring_url(profile_size) unless avatar.nil?
  end
  
  def can_reply_ticket
    privilege?(:reply_ticket)
  end
  
  def can_edit_ticket_properties
    privilege?(:edit_ticket_properties)
  end
  
  def can_delete_ticket
    privilege?(:delete_ticket)
  end

  def can_view_time_entries
    privilege?(:view_time_entries)
  end

  def can_edit_time_entries
    privilege?(:edit_time_entries)
  end
  
  def agent_signature
    Helpdesk::HTMLSanitizer.plain(agent.signature_html.gsub("</p>","\n").gsub("</div>","\n").gsub("<br>","\n").gsub("</br>","\n")) if (agent? && !agent.signature_html.blank?) 
  end

  def manage_scenarios
    privilege?(:manage_scenario_automation_rules)
  end

  def can_forward_ticket
    privilege?(:forward_ticket)
  end

  def can_edit_conversation
    privilege?(:edit_conversation)
  end

  def can_view_contacts
    privilege?(:view_contacts)
  end

  def can_delete_contact
    privilege?(:delete_contact)
  end

  def can_manage_tickets
    privilege?(:manage_tickets)
  end

  def can_view_solutions
    privilege?(:view_solutions)
  end

  def can_merge_or_split_tickets
    privilege?(:merge_or_split_ticket)
  end

end
