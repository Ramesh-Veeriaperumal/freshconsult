module Workers
	class ArchiveData
		@queue = "archive_reports_data"

		include Resque::Plugins::Status
		include Reports::ArchiveData
		include Redis::RedisKeys
		include Redis::ReportsRedis

		def perform
			options.symbolize_keys!
			archive(options)
			completed
			remove_reports_redis_key %(resque:status:#{uuid}) # uuid is job's unique id
			create_regeneration_job(options)			
		end

		def create_regeneration_job(options)
			id = options[:account_id]
		# Check if there is reports key for this account in redis to re-generate the data
			set_of_dates = set_reports_members REPORT_STATS_REGENERATE_KEY % {:account_id => id}
			return if set_of_dates.empty?
			export_hash = REPORT_STATS_EXPORT_HASH % {:account_id => id}
			accounts_re_job_id = get_reports_hash_value(export_hash, "re_job_id")
			accounts_re_job = Resque::Plugins::Status::Hash.get(accounts_re_job_id)
			if accounts_re_job.nil? or accounts_re_job.completed?
				re_job_id = Workers::RegenerateArchiveData.create({:account_id => id, :dates => set_of_dates})
				add_to_hash(export_hash, "re_job_id", re_job_id, 604800)
			elsif Rails.env.production?
				FreshdeskErrorsMailer.deliver_error_email(nil,accounts_re_job,nil,
				{:recipients => "srinivas@freshdesk.com",
					:subject => %(Reports regeneration data archiving job of Account ID : #{id} is 
																				#{accounts_re_job.status} for more than 24 hours)})
			end
		end

	end	
end