module Reports::GlanceReportControllerMethods

	def glance_report_data
		conditions = @sql_condition.join(" AND ")
    @data_obj = helpdesk_activity_query conditions
    @prev_data_obj = helpdesk_activity_query(conditions, true)
    @activity_data_hash = fetch_activity conditions
	end

end