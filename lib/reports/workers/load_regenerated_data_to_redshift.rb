module Reports
	module Workers
		module LoadRegeneratedDataToRedshift
			@queue = "load_regenerated_data_to_redshift"

			class << self

				include Reports::Constants
				include Reports::Redshift
				include Reports::CreateRedshiftStagingTable
				include Reports::ArchiveData

				def perform(args)
					args.symbolize_keys!
					date, hour = args[:date], args[:hour]
					folder, staging_table =  s3_folder(date,hour), staging_table_name(date,hour)
					merge_delete_query, merge_data_query = delete_regenerated_data(staging_table),merge_staging_to_base_table(staging_table) 
					regenerate_benchmark = {"s3_folder" => folder }
					
					files_arr = AwsWrapper::S3.list(S3_CONFIG[:reports_bucket], folder, false)
					return if files_arr.count == 0

					begin
						execute_redshift_query("set wlm_query_slot_count to 3;")
						regenerate_benchmark[" wlm_query_slot_count=> "] = execute_redshift_query("show wlm_query_slot_count;").getvalue(0,0)
						regenerate_benchmark[' table_create_time'] = Benchmark.measure {
							execute_redshift_query(create_staging_table(staging_table));
						}

						regenerate_benchmark[' data_dump_table_time'] = Benchmark.measure {
							query = %(COPY #{staging_table}(#{REDSHIFT_COLUMNS.join(", ")})
								from 's3://#{S3_CONFIG[:reports_bucket]}/#{folder}/redshift_' 
								credentials 'aws_access_key_id=#{S3_CONFIG[:access_key_id]};aws_secret_access_key=#{S3_CONFIG[:secret_access_key]}' 
								gzip delimiter '|' IGNOREHEADER 1 ROUNDEC REMOVEQUOTES MAXERROR 100000;)
							execute_redshift_query(query).clear
						}

						regenerate_benchmark["\n merge_delete_time"] = Benchmark.measure {
							regenerate_benchmark["\n no_of_merge_deleted_rows=> "] = execute_redshift_query(merge_delete_query).cmd_tuples()
						}

						regenerate_benchmark["\n merge_data_time"] = Benchmark.measure {
							regenerate_benchmark["\n no_of_merge_inserted_rows=> "] = execute_redshift_query(merge_data_query).cmd_tuples()
						}
						regenerate_benchmark["\n merge_delete_query=> "] = merge_delete_query
						regenerate_benchmark["\n merge_data_query=> "] = merge_data_query
						report_notification("Report regenerate data benchmark",regenerate_benchmark.to_s)
						# delete_all method is not there in aws-sdk version 2. When the below code is uncommented, use
						# AwsWrapper::S3.batch_delete to delete multiple files
						# Refer to load_data_redshift.rb
						# files_arr.delete_all
					rescue => e
						subject = "Error occured while loading regenerated data for folder =#{folder}"
						message =  e.message << "\n" << e.backtrace.join("\n")
						report_notification(subject,message)
						raise e
					ensure
						execute_redshift_query("set wlm_query_slot_count to 1;")
						execute_redshift_query("Drop table #{staging_table}")
					end
				end
				private
					def s3_folder(date,hour)
						%(#{$st_env_name}/#{regenerate_s3_folder(date,hour)})
					end

					def staging_table_name(date,hour)
		      	%(#{REPORTS_TABLE}#{STAGING_LABEL}#{date}_#{hour})
					end

					def delete_regenerated_data(staging_table_name)
					%(Delete from #{REPORTS_TABLE} using #{staging_table_name} where
						#{REPORTS_TABLE}.created_at = #{staging_table_name}.created_at and
						#{REPORTS_TABLE}.account_id = #{staging_table_name}.account_id;)
					end

					def merge_staging_to_base_table(staging_table_name)
						"Insert into #{REPORTS_TABLE} select * from #{staging_table_name};"
					end
			end
		end
	end
end