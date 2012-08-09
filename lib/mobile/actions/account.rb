module Mobile::Actions::Account

	JSON_INCLUDE = {
    :main_portal => {
      :only => [ :name, :preferences ],
      :methods => [ :logo_url, :fav_icon_url ]
    },
    :subscription => {
      :methods => [:is_paid_account]
    }
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
    to_json options
  end
  
end