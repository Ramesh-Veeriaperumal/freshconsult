class UserDrop < BaseDrop	

	include Rails.application.routes.url_helpers
	include Integrations::AppsUtil
	include DateHelper

	self.liquid_attributes += [:name, :first_name, :last_name, :email, :phone, :mobile, 
						:job_title, :time_zone, :twitter_id, :external_id, :language, :address, :description, :active, :unique_external_id]

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
		source.company_client_manager?
	end

	def firstname
   		source.first_name
   	end	
   	
	def lastname
		source.last_name
	end	
	def all_emails
		source.user_emails.pluck("email").join(",")
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

	def formatted_timezone
		Time.use_zone(source.time_zone) {
			Time.zone.to_s
		}
	end

	# !TODO This may be deprecated on a later release
	# Removed reference from placeholders UI
	def company_name
		@company_name ||= @source.company.name if @source.company
	end

	def before_method(method)
		required_field_value = @source.custom_field["cf_#{method}"] 
		required_field_type = @source.custom_field_types["cf_#{method}"]
		formatted_field_value(required_field_type, required_field_value)
	end

end
