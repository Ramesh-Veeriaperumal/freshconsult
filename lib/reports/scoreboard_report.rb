module Reports::ScoreboardReport
	include Reports::ActivityReport

	def list_of_champions()
		scoper.support_scores_all
	end

	def list_of_sharpshooters()
		scoper.support_scores_all.fastcall_resolution
	end

	def list_of_fcr()
		scoper.support_scores_all.firstcall_resolution
	end

	def list_of_happycustomers()
		scoper.support_scores_all.happycustomer_resolution
	end

	def scoper(starting_time = start_date, ending_time = end_date)
		Account.current.support_scores.created_at_inside(starting_time,ending_time)
	end

	def parse_from_date
		((params[:date_range].split(" - ")[0]) || params[:date_range]) if params[:date_range]
	end

	def parse_to_date
		((params[:date_range].split(" - ")[1]) || params[:date_range]) if params[:date_range]
	end

end
