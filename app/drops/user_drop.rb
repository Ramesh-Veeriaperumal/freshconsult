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
		name_part("given")
	end

	def lastname
		name_part("family")
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
	def company_name
		@company_name ||= @source.company.name if @source.company
	end


	private
		def name_part(part)
			part = parsed_name[part].blank? ? "particle" : part unless parsed_name.blank? and part == "family"
			parsed_name[part].blank? ? @source.name : parsed_name[part]
		end

		def parsed_name
			@parsed_name ||= Namae::Name.parse(@source.name)
		end
end
