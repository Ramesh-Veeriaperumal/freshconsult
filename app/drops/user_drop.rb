class UserDrop < BaseDrop
	liquid_attributes << :name << :email << :phone << :mobile << :job_title << :helpdesk_agent << :time_zone << :twitter_id 

	def initialize(source)
		super source
	end

	def profile_url
		source.avatar.nil? ? "/images/fillers/profile_blank_thumb.gif" : @source.avatar.expiring_url(:thumb, 300)
	end

	def id
		@source.id
	end

	def company_name		
		@company_name ||= @source.customer.name if @source.customer
	end

	def is_agent?
		source.agent?
	end

end