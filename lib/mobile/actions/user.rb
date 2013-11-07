module Mobile::Actions::User
	
	def to_mob_json_search
    options = { 
      :methods => [ :avatar_url, :is_agent, :is_customer,  :is_client_manager, :company_name,:user_time_zone],
      :only => [ :id, :name, :email, :mobile, :phone, :job_title, :twitter_id, :fb_profile_id ]
    }
    to_json options
  end
  
	def to_mob_json
    options = { 
      :methods => [ :original_avatar, :medium_avatar, :avatar_url, :is_agent, 
      							:is_customer, :recent_tickets, :is_client_manager, :company_name,
                    :can_reply_ticket, :can_edit_ticket_properties, :can_delete_ticket, :user_time_zone,
                    :can_view_time_entries, :can_edit_time_entries ],

      :only => [ :id, :name, :email, :mobile, :phone, :job_title, :twitter_id, :fb_profile_id ]
    }
    to_json options
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
end