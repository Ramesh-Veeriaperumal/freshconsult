module Reports
	module Workers
		module ArchiveDataByTimeZone
			@queue = "archive_reports_data"

			class << self
			
				include Reports::Constants
				include Redis::RedisKeys
				include Redis::ReportsRedis

				def perform(args)
					args.symbolize_keys!
					time_zones = TIMEZONES_BY_UTC_TIME[args[:hour]]
						Sharding.execute_on_all_shards do
						Sharding.run_on_slave do
						Account.current_pod.active_accounts.find_in_batches(:batch_size => 500 , 
																						:conditions => {:time_zone => time_zones}) do |accounts|
							accounts.each do |account|
								id = account.id
                begin
                  Time.zone = account.time_zone
                rescue ArgumentError => e
                  # we have problem with Kyev. In rails 2.3.18 Kyev , but in Rails 3.2.18 its corrected to Kyiv
                  # https://rails.lighthouseapp.com/projects/8994/tickets/2613-fix-spelling-of-kyiv-timezone
                  if e.message.include?("Invalid Timezone: Kyev")
                    Time.zone = "Kyiv" 
                  else
                    raise e
                  end
                end
								export_hash = REPORT_STATS_EXPORT_HASH % {:account_id => id}
								last_export_date, end_date = get_reports_hash_value(export_hash, "date"), args[:yesterday_date].to_date

								accounts_last_job_id = get_reports_hash_value(export_hash, "job_id")
								accounts_last_job = Resque::Plugins::Status::Hash.get(accounts_last_job_id)
								if (accounts_last_job.nil? or accounts_last_job.completed?) and (!(last_export_date.eql? end_date.to_s))
									start_date = last_export_date ? last_export_date.to_date + 1.day : end_date
									job_id = Reports::Workers::ArchiveData.create({:account_id => id, :start_date => start_date,
																												 :end_date => end_date})
									add_to_reports_hash(export_hash, "job_id", job_id, 604800)
	  						elsif (accounts_last_job and !accounts_last_job.completed? and Rails.env.production?)
	  							FreshdeskErrorsMailer.deliver_error_email(nil,accounts_last_job,nil,
	  							{:recipients => "srinivas@freshdesk.com",
	  								:subject => %(Reports data archiving job of Account ID : #{id} is 
	  																						#{accounts_last_job.status} for more than 24 hours)})
	  						end
							end
						end
					 end
					end
					end
			end
		end
	end
end