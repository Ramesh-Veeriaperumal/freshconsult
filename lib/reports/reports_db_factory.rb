module Reports
	class ReportsDBFactory

		include Reports::TicketStats

		def db(time_options = {})
			time = time_options[:base_time] ? time_options[:base_time] : time_options[:start_time]
			@stats_table_by_time ||= stats_table_exists? stats_table(Time.zone.parse(time))
			@stats_table_by_time ? Reports::MysqlQueries.new(time_options) : Reports::RedshiftQueries.new(time_options)
			# Reports::RedshiftQueries.new(time_options)
		end

	end
end
