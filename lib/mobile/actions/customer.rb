module Mobile::Actions::Customer
	JSON_OPTIONS = {
		:only => [:id, :name, :email, :mobile, :phone, :job_title, :twitter_id, :fb_profile_id]
	}
	def to_mob_json_search
		to_json JSON_OPTIONS
	end
end