class Reports::MysqlQueries < Reports::Queries

	include Reports::TicketStats

		def report_metrics
			%( #{select_received_tickets}, #{select_resolved_tickets}, #{select_backlog_tickets},
      IFNULL((SUM(if((#{resolve_time_condition('helpdesk_ticket_states.resolved_at')}),
				helpdesk_ticket_states.avg_response_time,NULL))/SUM(resolved_tickets))/3600,0) as avgresponsetime,
      IFNULL((SUM(if((#{resolve_time_condition('helpdesk_ticket_states.resolved_at')}),
				TIMESTAMPDIFF(SECOND, helpdesk_ticket_states.created_at, helpdesk_ticket_states.resolved_at),
				NULL))/SUM(resolved_tickets))/3600,0) as avgresolutiontime,
      IFNULL(SUM(if((#{resolve_time_condition('helpdesk_ticket_states.resolved_at')}),
				helpdesk_ticket_states.inbound_count,0))/SUM(resolved_tickets),0) as avgcustomerinteractions,
      IFNULL(SUM(if((#{resolve_time_condition('helpdesk_ticket_states.resolved_at')}),
				helpdesk_ticket_states.outbound_count,0))/SUM(resolved_tickets),0) as avgagentinteractions,
      IFNULL((SUM(if((#{time_condition('helpdesk_ticket_states.first_response_time')}),
				TIMESTAMPDIFF(SECOND, helpdesk_ticket_states.created_at, helpdesk_ticket_states.first_response_time),
				NULL))/#{select_first_resp_tickets})/3600,0) as avgfirstresptime,
      IFNULL(SUM(num_of_reopens),0) as num_of_reopens,
      IFNULL(SUM(assigned_tickets),0) as assigned_tickets,
      IFNULL(SUM(num_of_reassigns),0) as num_of_reassigns, IFNULL(SUM(fcr_tickets),0) as fcr_tickets,
      IFNULL(SUM(sla_tickets),0) as sla_tickets)
		end

		def select_received_tickets
			%(IFNULL(SUM(received_tickets),0) as received_tickets)
		end

		def select_resolved_tickets
			%(IFNULL(SUM(resolved_tickets),0) as resolved_tickets)
		end

		def select_backlog_tickets
  		%(count(if((helpdesk_tickets.status not in (4,5) and (helpdesk_ticket_states.resolved_at is NULL or 
      helpdesk_ticket_states.resolved_at > '#{@end_of_day_time.to_s(:db)}')),
      1,NULL)) as backlog_tickets)
  	end

  	def select_first_resp_tickets
  		%(count(if((#{time_condition('helpdesk_ticket_states.first_response_time')}), 1, NULL)))
  	end

  	def select_fcr_tickets
			%(IFNULL(SUM(fcr_tickets),0) as fcr_tickets)
		end

		def select_sla_tickets
			%(IFNULL(SUM(sla_tickets),0) as sla_tickets)
		end

  	def select_fcr_tickets_percentage
			%(IFNULL(SUM(fcr_tickets)/SUM(resolved_tickets),0) as fcr_tickets_percentage, #{total_resolved_tkts_count})
		end

		def select_sla_tickets_percentage
			%(IFNULL(SUM(sla_tickets)/SUM(resolved_tickets),0) as sla_tickets_percentage, #{total_resolved_tkts_count})
		end

		def select_sla_violation_tickets
			%(IFNULL(count(if((resolved_tickets = 1 and sla_tickets = 0),1,NULL))/SUM(resolved_tickets),0) as sla_tickets_percentage,
				#{total_resolved_tkts_count})
		end

  	def select_happy_customers
	    %(IFNULL(#{happy_rated_tkts(@end_of_day_time)}/#{total_rated_tkts(@end_of_day_time)},0) as happy_customers_percentage,
    			IFNULL(#{total_rated_tkts(@end_of_day_time)},0) as total_count)
	  end

	  def select_frustrated_customers
    	%(IFNULL(#{unhappy_rated_tkts(@end_of_day_time)}/#{total_rated_tkts(@end_of_day_time)},0) as frustrated_customers_percentage,
      IFNULL(#{total_rated_tkts(@end_of_day_time)},0) as total_count)
	  end

	  def total_resolved_tkts_count
			%(IFNULL(SUM(resolved_tickets),0) as total_count)
		end

	  def conditions
	  	%(#{ticket_conditions(@end_of_day_time)})
	  end

	  def stats_table_hash(options = {})
    	options.merge!({ :table => %( helpdesk_tickets ),
      :joins => %( left join (select account_id,ticket_id, #{select_ticket_stats}, union_stats_table.created_at created_at  
        from #{report_tables_union_query(@start_time, @end_time)} 
        as union_stats_table group by union_stats_table.account_id, union_stats_table.ticket_id) 
        as report_table on (helpdesk_tickets.id = report_table.ticket_id and 
        helpdesk_tickets.account_id = report_table.account_id) inner join #{tickets_join_query} )})
  	end

  	def execute(options)
  		ActiveRecord::Base.connection.select_all(stats_query(stats_table_hash(options)))
  	end

  	def resolve_time_condition(table_column_name)
				%(helpdesk_tickets.status IN (4,5) and #{time_condition(table_column_name)}) 
		end

		def time_condition(table_column_name)
			%(#{table_column_name} >= '#{Time.zone.parse(@start_time).to_s(:db)}' AND #{table_column_name} <= '#{@end_of_day_time.to_s(:db)}') 
		end

	end