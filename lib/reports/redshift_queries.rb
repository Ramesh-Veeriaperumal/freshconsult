class Reports::RedshiftQueries < Reports::Queries

	include Reports::Constants
	include Reports::Redshift

	def report_metrics
		%( #{select_received_tickets}, #{select_resolved_tickets}, #{select_backlog_tickets},
    NVL((SUM(avg_resp_time_by_bhrs)::float/NULLIF(SUM(resolved_tickets),0)),0) as avgresponsetime,
    NVL((SUM(resolution_time_by_bhrs)::float/NULLIF(SUM(resolved_tickets),0)),0) as avgresolutiontime,
    NVL(SUM(customer_interactions)::float/NULLIF(SUM(resolved_tickets),0),0) as avgcustomerinteractions,
    NVL(SUM(agent_interactions)::float/NULLIF(SUM(resolved_tickets),0),0) as avgagentinteractions,
    NVL((SUM(first_resp_time_by_bhrs)::float/NULLIF(SUM(first_responded_tickets),0)),0) as avgfirstresptime,
    NVL(SUM(num_of_reopens),0) as num_of_reopens,
    NVL(SUM(assigned_tickets),0) as assigned_tickets,
    NVL(SUM(num_of_reassigns),0) as num_of_reassigns, NVL(SUM(fcr_tickets),0) as fcr_tickets,
    NVL(SUM(sla_tickets),0) as sla_tickets)
	end

	def select_received_tickets
		%(NVL(SUM(received_tickets),0) as received_tickets)
	end

	def select_resolved_tickets
		%(NVL(SUM(resolved_tickets),0) as resolved_tickets)
	end

	def select_backlog_tickets(group_by_date = false)
		group_by_date ? %(SUM(backlog_tickets) as backlog_tickets) : 
    %(SUM(CASE WHEN report_table.created_at = '#{@end_time}' THEN backlog_tickets ELSE 0 END) as backlog_tickets)
	end

	def select_first_resp_tickets
		%(SUM(first_responded_tickets) as first_responded_tickets)
	end

	def select_fcr_tickets
		%(NVL(SUM(fcr_tickets),0) as fcr_tickets)
	end

	def select_sla_tickets
		%(NVL(SUM(sla_tickets),0) as sla_tickets)
	end

	def select_fcr_tickets_percentage
		%(NVL(SUM(fcr_tickets)::float/NULLIF(SUM(resolved_tickets),0),0) as fcr_tickets_percentage, #{total_resolved_tkts_count})
	end

	def select_sla_tickets_percentage
		%(NVL(SUM(sla_tickets)::float/NULLIF(SUM(resolved_tickets),0),0) as sla_tickets_percentage, #{total_resolved_tkts_count})
	end

	def select_sla_violation_tickets
		%(NVL(count(CASE WHEN (resolved_tickets = 1 and sla_tickets = 0) THEN 1 
				ELSE NULL END)::float/NULLIF(SUM(resolved_tickets),0),0) as sla_tickets_percentage, #{total_resolved_tkts_count})
	end

	def select_happy_customers
  %(NVL(SUM(CASE WHEN report_table.created_at = '#{@end_time}' THEN 
  	happy_rated_tickets ELSE 0 END)::float/NULLIF(#{total_rated_tickets},0),0) as happy_customers_percentage, 
    NVL(#{total_rated_tickets},0) as total_count)
	end

	def select_frustrated_customers
    %(NVL(SUM(CASE WHEN report_table.created_at = '#{@end_time}' THEN 
    	unhappy_rated_tickets ELSE 0 END)::float/NULLIF(#{total_rated_tickets},0),0) as frustrated_customers_percentage, 
      NVL(#{total_rated_tickets},0) as total_count)
	end

	def select_assigned_tickets
		%(NVL(SUM(assigned_tickets),0) as assigned_tickets)
	end

	def select_num_of_reopens
		%(NVL(SUM(num_of_reopens),0) as num_of_reopens)
	end

	def select_avg_agent_interactions
		%(NVL(SUM(agent_interactions),0) as avg_agent_interactions)
	end

	def select_avg_resolution_time
		%(NVL(SUM(resolution_time_by_bhrs),0) as avg_resolution_time)
	end

	def select_avg_first_response_time
		%(NVL(SUM(first_resp_time_by_bhrs),0) as avg_first_response_time)
	end

	def select_avg_response_time
		%(NVL(SUM(avg_resp_time_by_bhrs),0) as avg_response_time)
	end

	def total_resolved_tkts_count
		%(NVL(SUM(resolved_tickets),0) as total_count)
	end

	def total_rated_tickets
  	%(SUM((CASE WHEN report_table.created_at = '#{@end_time}' THEN happy_rated_tickets ELSE 0 END) + 
    (CASE WHEN report_table.created_at = '#{@end_time}' THEN neutral_rated_tickets ELSE 0 END) +
    (CASE WHEN report_table.created_at = '#{@end_time}' THEN unhappy_rated_tickets ELSE 0 END)))
	end

	def conditions
  	%(report_table.account_id = #{Account.current.id} AND report_table.created_at >= '#{@start_time}' AND 
  		report_table.created_at <= '#{@end_time}')
	end

	def execute(options)
		query = stats_query(options.merge!(:table => %(#{REPORTS_TABLE} as report_table)))
		execute_redshift_query(query, true)
	end
	
end