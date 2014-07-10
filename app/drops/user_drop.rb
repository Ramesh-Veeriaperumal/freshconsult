class UserDrop < BaseDrop	

	include ActionController::UrlWriter
	include Integrations::AppsUtil

	liquid_attributes << :name  << :first_name << :last_name << :email << :phone << :mobile << 
						:job_title  << :time_zone << :twitter_id << :external_id << :language << :address << 
						:description << :active

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

	# To access User's company details
	def company
		@company ||= @source.customer if @source.customer
	end

	# !TODO This may be deprecated on a later release
	def company_name
		@company_name ||= @source.customer.name if @source.customer
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
