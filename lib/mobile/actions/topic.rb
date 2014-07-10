module Mobile::Actions::Topic

	JSON_OPTIONS = { 
		:methods => [:stamp_name,:topic_desc], 
		:only => [ :title ]
	}
	
	def to_mob_json_search
		to_json JSON_OPTIONS
	end
	
end