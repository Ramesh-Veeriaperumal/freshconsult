module FreshdeskCore::Model

    MODEL_DEPENDENCIES = { :account => [{:dependant => :account_admin, :method => :destroy},
    									{:dependant => :all_email_configs, :method => :destroy_all},
    									{:dependant => :features, :method => :destroy_all},
    									{:dependant => :flexi_field_defs, :method => :destroy_all},
    									{:dependant => :data_export, :method => :destroy},
    									{:dependant => :email_commands_setting, :method => :destroy},
    									{:dependant => :conversion_metric, :method => :destroy},
    									{:dependant => :attachments, :method => :destroy_all},
    									{:dependant => :all_users, :method => :destroy_all},
    									{:dependant => :subscription, :method => :destroy},
    									{:dependant => :solution_categories, :method => :destroy_all},
    									{:dependant => :installed_applications, :method => :destroy_all},
    									{:dependant => :customers, :method => :destroy_all},
    									{:dependant => :sla_policies, :method => :destroy_all},
    									{:dependant => :account_va_rules, :method => :destroy_all},
    									{:dependant => :email_notifications, :method => :destroy_all},
    									{:dependant => :groups, :method => :destroy_all},
    									{:dependant => :forum_categories, :method => :destroy_all},
    									{:dependant => :business_calendar, :method => :destroy},
    									{:dependant => :form_customizer, :method => :destroy},
    									{:dependant => :ticket_fields, :method => :destroy_all},
    									{:dependant => :canned_responses, :method => :destroy_all},
    									{:dependant => :user_accesses, :method => :destroy_all},
    									{:dependant => :facebook_pages, :method => :destroy_all},
    									{:dependant => :facebook_posts, :method => :destroy_all},
    									{:dependant => :ticket_filters, :method => :destroy_all},
    									{:dependant => :twitter_handles, :method => :destroy_all},
    									{:dependant => :tweets, :method => :destroy_all},
    									{:dependant => :survey, :method => :destroy},
    									{:dependant => :scoreboard_ratings, :method => :destroy_all},
    									{:dependant => :survey_handles, :method => :destroy_all},
    									{:dependant => :day_pass_config, :method => :destroy},
    									{:dependant => :day_pass_usages, :method => :destroy_all},
    									{:dependant => :day_pass_purchases, :method => :destroy_all},
    									{:dependant => :data_import, :method => :destroy},
    									{:dependant => :tags, :method => :destroy_all}
    	] }

	def perform_destroy(obj)
	  dependants = MODEL_DEPENDENCIES.fetch(exract_key_from_object(obj),{})
	  dependants.each do |dependant_hash|
	  	dependant_value = obj.send(dependant_hash.fetch(:dependant))
	  	dependant_value.send(dependant_hash.fetch(:method)) if dependant_value
	  end
	  obj.destroy
	end

	def exract_key_from_object(obj)
	  obj.class.name.downcase.to_sym
	end
end