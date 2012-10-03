module Reports::GamificationReport
	include Reports::ActivityReport

	def champions
		scoper.total_score
	end

	def sharpshooters
		scoper.total_score.fast
	end

	def first_call_resolution
		scoper.total_score.first_call
	end	

	def happy_customers
		scoper.total_score.happy_customer
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
