module Reports::TicketStats

	include RedisKeys
	include Helpdesk::Ticketfields::TicketStatus

	REPORT_STATS = ['account_id', 'ticket_id', 'created_at','created_hour','resolved_hour',
		'received_tickets','resolved_tickets','num_of_reopens','assigned_tickets','num_of_reassigns',
		'fcr_tickets','sla_tickets']

	def stats_table(time = Time.zone.now, account = Account.current)
		time = time.in_time_zone(account.time_zone)
		year, month = time.year, time.month
		"ticket_stats_#{year}_#{month}"
	end

	def stats_table_exists?(table)
		ActiveRecord::Base.connection.table_exists? table
	end

	def set_reports_redis_key(account_id, date)
		begin
			return unless stats_table_exists?(stats_table(date))
			export_hash = REPORT_STATS_EXPORT_HASH % {:account_id => account_id}
			last_export_date = get_hash_value(export_hash, "date")
			regenerate_date = date.strftime('%Y-%m-%d')
			return if (last_export_date && regenerate_date.to_date > last_export_date.to_date)
			reports_redis_key = REPORT_STATS_REGENERATE_KEY % {:account_id => account_id}
			add_to_set(reports_redis_key, regenerate_date, 864000)
		rescue Exception => e
			NewRelic::Agent.notice_error(e)
		end
	end

	def tickets_join_query(ff_cols = []) # ff_cols parameter change does not handled for mysql_queries
		%( helpdesk_schema_less_tickets on helpdesk_tickets.id = helpdesk_schema_less_tickets.ticket_id 
		and helpdesk_tickets.account_id = helpdesk_schema_less_tickets.account_id INNER JOIN 
		helpdesk_ticket_states on helpdesk_tickets.id = helpdesk_ticket_states.ticket_id and 
		helpdesk_tickets.account_id = helpdesk_ticket_states.account_id INNER JOIN users 
		on helpdesk_tickets.requester_id = users.id  and users.account_id = helpdesk_tickets.account_id 
		left join customers on users.customer_id = customers.id and users.account_id = customers.account_id %s) % (
		ff_cols.empty? ? "" : " INNER JOIN flexifields on helpdesk_tickets.id = flexifields.flexifield_set_id  and 
		helpdesk_tickets.account_id = flexifields.account_id and flexifields.flexifield_set_type = 'Helpdesk::Ticket'")
	end

	def ticket_conditions(time, account_id = Account.current.id)
		%( helpdesk_tickets.account_id = #{account_id} and 
			helpdesk_tickets.created_at <= '#{time.to_s(:db)}' and 
			(helpdesk_ticket_states.resolved_at is NULL or helpdesk_ticket_states.resolved_at > '#{time.ago(2.months).to_s(:db)}') and 
			helpdesk_tickets.spam = false and helpdesk_tickets.deleted = false and helpdesk_tickets.status > 0 )
	end

	def total_rated_tkts(time)
		%(count(if((helpdesk_schema_less_tickets.#{Helpdesk::SchemaLessTicket.survey_rating_column} IS NOT NULL and 
			(#{survey_conditions(time)})),1,NULL)))
	end

	def happy_rated_tkts(time)
		%(count(if((helpdesk_schema_less_tickets.#{Helpdesk::SchemaLessTicket.survey_rating_column} = 1 and 
			(#{survey_conditions(time)})),1,NULL)))
	end

	def neutral_rated_tkts(time)
		%(count(if((helpdesk_schema_less_tickets.#{Helpdesk::SchemaLessTicket.survey_rating_column} = 2 and 
			(#{survey_conditions(time)})),1,NULL)))
	end

	def unhappy_rated_tkts(time)
		%(count(if((helpdesk_schema_less_tickets.#{Helpdesk::SchemaLessTicket.survey_rating_column} = 3 and 
			(#{survey_conditions(time)})),1,NULL)))
	end

	def survey_conditions(time)
		%(helpdesk_schema_less_tickets.#{Helpdesk::SchemaLessTicket.survey_rating_updated_at_column} IS NULL or 
				helpdesk_schema_less_tickets.#{Helpdesk::SchemaLessTicket.survey_rating_updated_at_column} < '#{time.to_s(:db)}')
	end

# following are mysql_queries related methods, which we are not using now.
	def select_ticket_stats
		%( SUM(received_tickets) received_tickets, SUM(resolved_tickets) resolved_tickets, 
			SUM(num_of_reopens) num_of_reopens,SUM(assigned_tickets) assigned_tickets,
			SUM(num_of_reassigns) num_of_reassigns, SUM(sla_tickets) sla_tickets,
			SUM(fcr_tickets) fcr_tickets )
	end

	def report_tables_union_query(start_date, end_date, account = Account.current)
		tables_arr = tables_btn(Date.parse(start_date), Date.parse(end_date))
		length, acc_cond = tables_arr.length, "account_id = #{account.id}"
		return %( (select * from #{tables_arr[0]} where #{acc_cond} and created_at >= '#{start_date}' and 
			created_at <= '#{end_date}') ) if length == 1
		join_str = ""
		tables_arr.each_index do |index|
			join_str += " (select * from #{tables_arr[index]} "
			join_str += (index == 0) ? " where #{acc_cond} and created_at >= '#{start_date}') " : 
				(index == tables_arr.length-1) ? 	" where #{acc_cond} and created_at <= '#{end_date}') " :	
				" where #{acc_cond}) "
			join_str += " UNION ALL " unless index == tables_arr.length-1
		end
		%( ( #{join_str} ) )
	end

	def tables_btn(start_date, end_date)
	  tables = []
	  m = start_date
	  while m <= end_date do
	    tables << "ticket_stats_#{m.year}_#{m.month}"
	    m = m >> 1
	  end
	  tables << "ticket_stats_#{m.year}_#{m.month}" if m.month == end_date.month
	  tables
	end

end