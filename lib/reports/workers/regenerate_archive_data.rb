module Reports
	module Workers
		class RegenerateArchiveData
			extend Resque::AroundPerform 
			@queue = "regenerate_archive_reports_data"

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
					@s3_folder = ARCHIVE_DATA_FILE % {:date => date, :account_id => id}
					deleted_result = delete_outdated(id, date)
					num_of_deleted_rows = deleted_result.cmd_tuples
					deleted_result.clear
					load_regenerated_data
					remove_reports_member REPORT_STATS_REGENERATE_KEY % {:account_id => id}, date
				end
				completed
				remove_reports_redis_key %(resque:status:#{uuid}) # uuid is job's unique id
			end

			# delete out dated data for stats_date and account
			def delete_outdated(account_id, date)
				query = %(DELETE from #{REPORTS_TABLE} where account_id = #{account_id} and #{REPORTS_DATE_COLUMN} = '#{date} 00:00:00')
				execute_redshift_query(query)
			end

			# Load the regenerated data into Redshift
			def load_regenerated_data
				query = %(COPY #{REPORTS_TABLE}(#{REDSHIFT_COLUMNS.join(", ")})
						from 's3://#{S3_CONFIG[:reports_bucket]}/#{$st_env_name}/#{@s3_folder}/redshift_#{@s3_folder}.csv' 
						credentials 'aws_access_key_id=#{S3_CONFIG[:access_key_id]};aws_secret_access_key=#{S3_CONFIG[:secret_access_key]}' 
						delimiter '|' IGNOREHEADER 1 ROUNDEC REMOVEQUOTES MAXERROR 100000;)	
				execute_redshift_query(query).clear
				# deleting file from s3
				AwsWrapper::S3Object.delete($st_env_name+'/'+@s3_folder+'/redshift_'+@s3_folder+'.csv', S3_CONFIG[:reports_bucket])
			end


		end
	end
end