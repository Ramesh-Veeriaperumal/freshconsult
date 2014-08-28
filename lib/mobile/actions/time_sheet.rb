module Mobile::Actions::TimeSheet

	JSON_OPTIONS = {
		:only => [:executed_at, :time_spent, :billable, :note, :id, :user_id],
		:methods => [:agent_name]
	}
	
	def to_mob_json
		as_json(JSON_OPTIONS,false)
	end

end