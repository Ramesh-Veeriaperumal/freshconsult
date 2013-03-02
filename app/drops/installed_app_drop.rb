class InstalledAppDrop < BaseDrop

	def initialize(source)
		super source
	end

	def id
		@source.id
	end

	def user_access_token
		Rails.logger.debug "\n\nUser id is:  #{@context['current_user'].id}\n\n"
		Rails.logger.debug "Inst_app: #{@source.inspect}\n\n"
		@source.user_access_token @context['current_user'].id
	end

	def user_registered_email
		@source.user_registered_email @context['current_user'].id
	end

	def oauth_url
		Liquid::Template.parse(@source.application.options[:oauth_url]).render({
			"portal_id" => @context['portal_id'],
			"account_id" => @context['portal_id'] # Just for Salesforce
		})
	end

	def events_list
        if(@source.application.name == 'google_calendar')
          events_list = (Integrations::IntegratedResource.find(:all,
	      :conditions => ["installed_application_id=? AND local_integratable_id=?", 
          @source.id, @context['ticket'].id]).map { |i| 
          	"{'remote_integratable_id': '#{i.remote_integratable_id}', 'integrated_resource_id': #{i.id}}"
          }).join(", ")
        end
	end

end