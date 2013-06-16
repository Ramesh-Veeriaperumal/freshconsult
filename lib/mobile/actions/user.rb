module Mobile::Actions::User
	
	def to_mob_json
    options = { 
      :methods => [ :original_avatar, :medium_avatar, :avatar_url, :is_agent, 
      							:is_customer, :recent_tickets, :is_client_manager, :company_name,
                    :can_reply_ticket, :can_edit_ticket_properties, :can_delete_ticket ],
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

end