module Reports::ArchiveDataMigration

	START_DATE = "2013-01-01"

	def data_migration
			Account.active_accounts.find_in_batches(:batch_size => 500) do |accounts|
				accounts.each do |account|
					Time.zone = account.time_zone
					START_DATE.to_date.upto(Time.zone.now.to_date.yesterday) do |day|
						start_time = Time.zone.parse(day.strftime("%Y-%m-%d 00:00:00"))
						Resque.enqueue(Workers::ArchiveData, {:account_id => account.id, 
							:stats_date => start_time.strftime("%Y-%m-%d 00:00:00"),
							:stats_end_time => start_time.strftime("%Y-%m-%d 23:59:59") })
					end
				end
			end
	end

end
