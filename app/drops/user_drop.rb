class UserDrop < BaseDrop	

	include Rails.application.routes.url_helpers
	include Integrations::AppsUtil

	self.liquid_attributes += [:name, :first_name, :last_name, :email, :phone, :mobile, 
						:job_title, :time_zone, :twitter_id, :external_id, :language, :address, :description, :active]

	def initialize(source)
		super source
	end

	def profile_url
		source.avatar.nil? ? false : profile_image_user_path(@source)
	end

	def id
		@source.id
	end

	def address
		@source.address.nil? ? '' : @source.address.gsub(/\n/, '<br/>')
	end

	def is_agent
		source.helpdesk_agent
	end
  
	def is_client_manager
		source.privilege?(:client_manager)
	end

	def firstname
   		source.first_name
   	end	
   	
	def lastname
		source.last_name
	end	
	def all_emails
		source.user_emails.collect(&:email)
	end

	def recent_tickets
		source.tickets.visible.newest(5)
	end

	def open_and_pending_tickets
		source.open_tickets
	end

	def closed_and_resolved_tickets
		source.tickets.visible.resolved_and_closed_tickets
	end	

	# To access User's company details
	def company
		@company ||= @source.company if @source.company
	end

	# !TODO This may be deprecated on a later release
	# Removed reference from placeholders UI
	def company_name
		@company_name ||= @source.company.name if @source.company
	end

	def before_method(method)
		custom_fields = @source.custom_field
		field_types =  @source.custom_field_types
		if(custom_fields["cf_#{method}"] || field_types["cf_#{method}"])
	    unless custom_fields["cf_#{method}"].blank?
	      return custom_fields["cf_#{method}"].gsub(/\n/, '<br/>') if field_types["cf_#{method}"] == :custom_paragraph
	    end
	    custom_fields["cf_#{method}"] 
	  else
	    super
	  end
	end

end
