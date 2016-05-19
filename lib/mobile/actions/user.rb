module Mobile::Actions::User

	include Mobile::Actions::Push_Notifier

  CONFIG_JSON_INCLUDE = {
      only: [:id], 
      :include =>{ :roles => { :only => [:id, :name, :default_role] } },
      :methods => [:display_name, :can_delete_ticket, :can_view_contacts, :can_delete_contact, :can_edit_ticket_properties, 
        :can_view_solutions, :can_merge_or_split_tickets,:can_reply_ticket, :manage_scenarios,:can_view_time_entries,
        :can_edit_time_entries, :can_forward_ticket, :can_edit_conversation, :can_manage_tickets,:user_time_zone,:can_manage_contact, :avatar_url, :original_avatar, :medium_avatar]
      }

	def to_mob_json_search(opts={})
    options = { 
      :only => [ :id, :name, :email, :mobile, :phone, :job_title, :twitter_id, :fb_profile_id ,:address,
        :customer_id,:description,:language,:user_role],
      :include => { :company => { :only => [:id,:name,:account_id,:description,:note,:domains] }},
      :methods => [ :avatar_url, :is_agent, :is_customer,  :is_client_manager, :company_name,:user_time_zone,:company_id]
      
    }.merge(opts)
    as_json(options,true)
  end
  
	def to_mob_json(opts={})
    options = { 
      :methods => [ :original_avatar, :medium_avatar, :avatar_url, :is_agent, 
      							:is_customer, :user_recent_tickets, :is_client_manager, :company_name,
                    :can_reply_ticket, :can_edit_ticket_properties, :can_delete_ticket, :user_time_zone,
                    :can_view_time_entries, :can_edit_time_entries, :agent_signature,:company_id,:user_emails,:contact_fields,:custom_field ],
      :include => { :company => { :only => [:id,:name,:account_id,:description,:note,:domains], 
                    :methods => [:company_custom_fields,:custom_field] },
                    },         
      :only => [ :id, :name, :email, :mobile, :phone, :job_title, :twitter_id, :fb_profile_id,:address,
        :customer_id,:description,:helpdesk_agent,:language,:user_role ]
    }.merge(opts)
    as_json(options,true)
  end

  def as_config_json
    as_json(CONFIG_JSON_INCLUDE,true)
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

  def can_manage_contact
    privilege?(:manage_contacts) and !User.current.deleted? and !User.current.spam? and !User.current.blocked?
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
  
  #referred from CompaniesController 
  def user_recent_tickets
    self.account.tickets.permissible(self).
        requester_active(self).visible.newest(10).find(:all, 
          :select => [:id,:display_id,:subject,:status,:priority,:created_at,:requester_id,:source,:spam,:deleted,:responder_id])
  end

  def contact_fields
    Account.current.contact_form.contact_fields
  end

  def company_custom_fields
    Account.current.company_form.custom_company_fields
  end

end
