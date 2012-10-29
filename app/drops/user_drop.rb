class UserDrop < BaseDrop

	liquid_attributes << :name << :email << :phone << :mobile << :job_title << :user_role << :time_zone

	def initialize(source)
		super source
	end

	def profile_url
		source.avatar.nil? ? "/images/fillers/profile_blank_thumb.gif" : source.avatar.content.url(:thumb)
	end

	def id
		@source.id
	end

	def company_name		
		@company_name ||= @source.customer.name if @source.customer
	end

	def agent?
		source.agent?
	end

end