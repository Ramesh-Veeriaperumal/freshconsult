module Reports
	module Workers
		class RegenerateReportData
			extend Resque::AroundPerform 
			@queue = "regenerate_report_data"

			include Resque::Plugins::Status
			include Redis::RedisKeys
			include Redis::ReportsRedis
			include Reports::Constants
			include Reports::Redshift
			include Reports::ArchiveData

			def perform
				options.symbolize_keys!
				id, dates_set = options[:account_id], options[:dates]
				export_hash = REPORT_STATS_EXPORT_HASH % {:account_id => id}
				last_export_date = Time.zone.parse(get_reports_hash_value(export_hash, "date"))
				dates_set.each do |date|
					next if last_export_date <= Time.zone.parse(date)
					args = {:account_id => id, :start_date => date, :end_date => date, :regenerate => true}
					archive(args)
					remove_reports_member REPORT_STATS_REGENERATE_KEY % {:account_id => id}, date
				end
				completed
				remove_reports_redis_key %(resque:status:#{uuid}) # uuid is job's unique id
			end
		end
	end
end