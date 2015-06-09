module Mobile::Actions::Account

	include Mobile::Actions::Push_Notifier

	JSON_INCLUDE = {
    :main_portal => {
      :only => [ :name, :preferences ],
      :methods => [ :logo_url, :fav_icon_url ]
    },
    :subscription => {
      :methods => [:is_paid_account]
    }
  }

  CONFIG_JSON_INCLUDE = {
      only: [:id], 
      :methods => [:portal_name, :full_domain, :social_feature, :timesheets_feature, :freshfone_feature]
  }

	def to_mob_json(deep=false)
    json_include = JSON_INCLUDE
    options = {
      :only => [:name],
    }
    if deep
    	json_include.merge!({
		    :canned_responses => {
		      :methods => [ :my_canned_responses ],
		      :only => [ :title, :id ]
		    },
		    :scn_automations =>{
		      :only => [ :id, :name ]
		    },
		    :twitter_handles => {
		      :only => [ :id, :screen_name ]
		    }
		  })
      options.merge!({
        :methods => [ :reply_emails, :bcc_email ],
      })
    end
    options[:include] = json_include;
    as_json options
  end

  def as_config_json
    as_json(CONFIG_JSON_INCLUDE)
  end

  def timesheets_feature
    features?(:timesheets)
  end

  def freshfone_feature
    freshfone_enabled?
  end

  def social_feature
    (features?(:twitter) && User.current.privilege?(:manage_tickets)) && !twitter_handles_from_cache.blank?
  end

end
