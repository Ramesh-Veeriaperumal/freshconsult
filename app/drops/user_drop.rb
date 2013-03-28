class UserDrop < BaseDrop	

	include ActionController::UrlWriter

	liquid_attributes << :name  << :first_name << :last_name << :email << :phone << :mobile << 
						:job_title << :time_zone << :twitter_id  

  include Integrations::AppsUtil

	def initialize(source)
		super source
	end

	def profile_url
		source.avatar.nil? ? false : profile_image_user_path(@source)
	end

	def id
		@source.id
	end

	def company_name		
		@company_name ||= @source.customer.name if @source.customer
	end

	def is_agent
		source.helpdesk_agent
	end
  
  def is_client_manager
    source.privilege?(:client_manager)
  end

	def firstname
		name_part(:first)
	end

	def lastname
		name_part(:last)
	end

	private
		def name_part(part)
			parsed_name[part].blank? ? parsed_name[:clean] : parsed_name[part]
		end

		def parsed_name
			@parsed_name ||= People::NameParser.new.parse(@source.name)
		end
end