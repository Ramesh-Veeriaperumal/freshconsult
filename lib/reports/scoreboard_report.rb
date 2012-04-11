module Reports::ScoreboardReport
	include Reports::ActivityReport

	def list_of_champions()
		scoper.support_scores_all
	end

	def list_of_sharpshooters()
		scoper.support_scores_all.fastcall_resolution
	end

	def scoper(starting_time = start_date, ending_time = end_date)
		Account.current.support_scores.created_at_inside(starting_time,ending_time)
	end	
end
