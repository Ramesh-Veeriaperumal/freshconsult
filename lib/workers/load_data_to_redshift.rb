module Workers
	module LoadDataToRedshift
		@queue = "load_reports_data_to_redshift"

		class << self

			include Reports::Constants
			include Reports::Redshift

			def perform(args)
				args.symbolize_keys!
				date, hour = args[:date], args[:hour].to_i
				if hour == 0
					time_arr = date.split("_") # date will be in "2013_01_01" format
					datetime = Time.utc(time_arr[0],time_arr[1],time_arr[2],hour).ago(3600) # we will load the data from folder which got created one hour ago 
					date, hour = datetime.strftime('%Y_%m_%d'), datetime.hour
				else
					hour = hour - 1
				end
				@s3_folder = %(#{$st_env_name}/#{date}_#{hour})
				bucket = AWS::S3::Bucket.new(S3_CONFIG[:reports_bucket])
				files_arr = bucket.objects.with_prefix(@s3_folder)
				return if files_arr.count == 0

				query = %(COPY #{REPORTS_TABLE}(#{REDSHIFT_COLUMNS.join(", ")})
						from 's3://#{S3_CONFIG[:reports_bucket]}/#{@s3_folder}/redshift_' 
						credentials 'aws_access_key_id=#{S3_CONFIG[:access_key_id]};aws_secret_access_key=#{S3_CONFIG[:secret_access_key]}' 
						delimiter '|' IGNOREHEADER 1 ROUNDEC REMOVEQUOTES MAXERROR 100;)
				execute_redshift_query(query).clear
				# vacuum_query = %(VACUUM SORT ONLY #{REPORTS_TABLE}) # sort only vacuum query to sort the newly added rows
				# execute_redshift_query(vacuum_query).clear
				# delete the uploaded files
				files_arr.delete_all
				# files_arr.each {|obj| obj.delete}
			end

		end
	end
end