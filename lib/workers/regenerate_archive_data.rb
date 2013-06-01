module Workers
	class RegenerateArchiveData
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
			dates_set.each do |date|
				args = {:account_id => id, :start_date => date, :end_date => date, :regenerate => true}
				archive(args)
				@s3_folder = ARCHIVE_DATA_FILE % {:date => date, :account_id => id}
				deleted_result = delete_outdated(id, date)
				num_of_deleted_rows = deleted_result.cmd_tuples
				deleted_result.clear
				# This check is to handle the following scenario....
				# If regeneration (archiving + loading data to redshift) for an account for a date happens before 
				# the normal archiving, then data duplication can happen after the normal archiving data loaded into redshift.
				# This case can happen during 1 month data migration into redshift
				if num_of_deleted_rows == 0
					AWS::S3::S3Object.delete($st_env_name+'/'+@s3_folder+'/redshift_'+@s3_folder+'.csv', S3_CONFIG[:reports_bucket])
					remove_reports_member REPORT_STATS_REGENERATE_KEY % {:account_id => id}, date
					next
				end
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
					delimiter '|' IGNOREHEADER 1 ROUNDEC REMOVEQUOTES MAXERROR 100;)	
			execute_redshift_query(query).clear
			# deleting file from s3
			AWS::S3::S3Object.delete($st_env_name+'/'+@s3_folder+'/redshift_'+@s3_folder+'.csv', S3_CONFIG[:reports_bucket])
		end


	end
end