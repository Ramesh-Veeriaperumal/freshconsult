module Reports::PopulateStatsData

	def stats_data(start_time)
			Account.active_accounts.find_in_batches(:batch_size => 500) do |accounts|
				accounts.each do |account|
					Time.zone = account.time_zone
					Resque.enqueue(Workers::PopulateStatsDataWorker, {:account_id => account.id, :start_time => start_time, 
						:end_time => Time.zone.now.to_s})
				end
			end
	end
	
end

