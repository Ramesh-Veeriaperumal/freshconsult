module Reports
	module ArchiveData

		include Reports::Constants
		include Reports::TicketStats
		include Redis::RedisKeys
		include Redis::ReportsRedis

		attr_accessor :stats_date, :stats_date_time, :stats_end_time, :stats_table_name

			def archive(options)
				account_id, regenerate = options[:account_id], options.key?(:regenerate)
				start_date, end_date = options[:start_date].to_date, options[:end_date].to_date
				Sharding.run_on_slave do
					account = Account.current
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
					start_date.upto(end_date) do |day|
						@stats_date, @stats_end_time = day.strftime("%Y-%m-%d 00:00:00"), Time.zone.parse(day.strftime("%Y-%m-%d 23:59:59"))
						@stats_date_time = Time.zone.parse(stats_date)
						@stats_table_name = stats_table(stats_date_time, account)
						load_archive_data(account, regenerate)
						add_to_reports_hash(REPORT_STATS_EXPORT_HASH % {:account_id => account_id},"date",
																		stats_date_time.strftime("%Y-%m-%d"),604800) unless regenerate
					end
				end 
			end

			def load_archive_data(account, regenerate = false)
				begin
					ff_cols = FlexifieldDefEntry.dropdown_custom_fields(account).sort	
				rescue Exception => e
					ff_cols = []
				end
				def_columns = select_def_columns(ff_cols)

				query_str = " select #{select_aggregate_columns}, #{def_columns} from #{join_query(ff_cols)} "\
    								" where #{conditions(account.id)} group by #{def_columns}"
				reporting_data = ActiveRecord::Base.connection.select_all(query_str)
  			# write data into csv
  			temp_file = ARCHIVE_DATA_FILE % {:date => stats_date_time.strftime("%Y-%m-%d"), :account_id => account.id}
				csv_file_path = File.join(FileUtils.mkdir_p(CSV_FILE_DIR),%(#{temp_file}.csv))
				csv_string = CSVBridge.open(csv_file_path, "w", {:col_sep => "|"}) do |csv|
     			csv << (REPORT_COLUMNS + %w(created_at))
     			reporting_data.each do |hash| 
     				val_array = REPORT_COLUMNS.inject([]) do |values, col_name|
     					values << ( !hash.key?(col_name) ? "\\N" : (hash[col_name].nil? ? "\\N" : mysql_escape(hash[col_name])))
     					values
     				end
     				val_array << stats_date
     				csv << val_array
     			end
      	end
      	# reporting_data.free

      	utc_time = Time.now.utc
      	utc_date, utc_hour = utc_time.strftime('%Y_%m_%d'), utc_time.hour

      	if account.features?(:reports_regenerate_data) && regenerate
	      	s3_folder = regenerate_s3_folder(utc_date, utc_hour) 
	      else
      		s3_folder = regenerate ? temp_file : %(#{utc_date}_#{utc_hour})
      	end

      	AwsWrapper::S3Object.store("#{$st_env_name}/#{s3_folder}/redshift_#{temp_file}.csv", File.read(csv_file_path), S3_CONFIG[:reports_bucket])
      	
				File.delete(csv_file_path)
			end

			def mysql_escape(object)
				return object unless object.is_a?(String)
		    Mysql2::Client.escape(object)
		  end
			
			def select_def_columns(ff_cols)
				def_cols = DEFAULT_TICKET_COLUMNS.map {|c| "helpdesk_tickets.#{c}"}.join(",")
				def_schema_cols = DEFAULT_SCHEMA_LESS_TICKET_COLUMNS.map {|c| "helpdesk_schema_less_tickets.#{c}"}.join(",")
				user_cols = USER_COLUMNS.map {|c| "users.#{c}"}.join(",")
				stat_cols = STATS_COLUMNS.map {|c| "#{stats_table_name}.#{c}"}.join(",")
				custom_fields = ff_cols.map{|c| "flexifields.#{c}"}.join(",")
				%(#{def_cols}, #{def_schema_cols}, #{user_cols}, #{stat_cols} %s) % (custom_fields.empty? ? "" : ", #{custom_fields}")
			end

			# backlog_columns and all survey rated tickets count will be calculated till the end of the selected time period
			# avg_response_time,agent_interactions,customer_interactions will be considered only for resolved tickets
			def select_aggregate_columns
				%( CAST(IFNULL(SUM(received_tickets),0) as SIGNED) as received_tickets, CAST(IFNULL(SUM(resolved_tickets),0) as SIGNED) as resolved_tickets, 
				count(if((helpdesk_tickets.status not in (4,5) and (helpdesk_ticket_states.resolved_at is NULL or 
      	helpdesk_ticket_states.resolved_at > '#{stats_end_time.to_s(:db)}')),1,NULL)) as backlog_tickets,
				SUM(if((#{resolve_time_condition('helpdesk_ticket_states.resolved_at')}),
					helpdesk_ticket_states.avg_response_time,NULL)) as avg_resp_time,
				SUM(if((#{resolve_time_condition('helpdesk_ticket_states.resolved_at')}),
					helpdesk_ticket_states.avg_response_time_by_bhrs,NULL)) as avg_resp_time_by_bhrs,
				count(if((#{time_condition('helpdesk_ticket_states.first_response_time')}), 1, NULL)) as first_responded_tickets, 
				CAST(SUM(if((#{time_condition('helpdesk_ticket_states.first_response_time')}),
					TIMESTAMPDIFF(SECOND, helpdesk_ticket_states.created_at, helpdesk_ticket_states.first_response_time),NULL)) as SIGNED) 
					as first_resp_time,
				CAST(SUM(if((#{time_condition('helpdesk_ticket_states.first_response_time')}),
					helpdesk_ticket_states.first_resp_time_by_bhrs,NULL)) as SIGNED) as first_resp_time_by_bhrs,
				CAST(SUM(if((#{resolve_time_condition('helpdesk_ticket_states.resolved_at')}),
					TIMESTAMPDIFF(SECOND, helpdesk_ticket_states.created_at, helpdesk_ticket_states.resolved_at),NULL)) as SIGNED)
					as resolution_time,
				CAST(SUM(if((#{resolve_time_condition('helpdesk_ticket_states.resolved_at')}),
					helpdesk_ticket_states.resolution_time_by_bhrs,NULL)) as SIGNED) as resolution_time_by_bhrs,
				CAST(SUM(if((#{resolve_time_condition('helpdesk_ticket_states.resolved_at')}),
					helpdesk_ticket_states.inbound_count,0)) as SIGNED) as customer_interactions,
				CAST(SUM(if((#{resolve_time_condition('helpdesk_ticket_states.resolved_at')}),
					helpdesk_ticket_states.outbound_count,0)) as SIGNED) as agent_interactions,
				CAST(IFNULL(SUM(num_of_reopens),0) as SIGNED) as num_of_reopens,
				CAST(IFNULL(SUM(assigned_tickets),0) as SIGNED) as assigned_tickets, CAST(IFNULL(SUM(num_of_reassigns),0) as SIGNED) as num_of_reassigns,
				CAST(IFNULL(SUM(fcr_tickets),0) as SIGNED) as fcr_tickets,CAST(IFNULL(SUM(sla_tickets),0) as SIGNED) as sla_tickets,
				#{happy_rated_tkts(stats_end_time)} as happy_rated_tickets,
				#{neutral_rated_tkts(stats_end_time)} as neutral_rated_tickets,
				#{unhappy_rated_tkts(stats_end_time)} as unhappy_rated_tickets)
			end

			def join_query(ff_cols = [])
				%( helpdesk_tickets left join #{stats_table_name} on (helpdesk_tickets.id = 
					#{stats_table_name}.ticket_id and helpdesk_tickets.account_id = #{stats_table_name}.account_id and 
					#{stats_table_name}.created_at = '#{stats_date}') inner join #{tickets_join_query(ff_cols)})
			end

			def conditions(account_id)
				%( #{ticket_conditions(stats_end_time,account_id)} )
			end

			def resolve_time_condition(table_column_name)
				%(helpdesk_tickets.status IN (4,5) and #{time_condition(table_column_name)}) 
			end

			def time_condition(table_column_name)
				%(#{table_column_name} >= '#{stats_date_time.to_s(:db)}' AND #{table_column_name} <= '#{stats_end_time.to_s(:db)}') 
			end

			def report_notification(subject,message)
				notification_topic = SNS["reports_notification_topic"]
      	DevNotification.publish(notification_topic, subject, message)
			end

			def regenerate_s3_folder(date,hour)
				%(#{REGENERATE_LABEL}#{date}_#{hour})
			end
	end
end