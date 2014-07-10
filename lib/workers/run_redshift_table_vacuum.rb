module Workers
	module RunRedshiftTableVacuum
		@queue = "load_reports_data_to_redshift"

		class << self
      include Reports::Constants
			include Reports::Redshift

      def perform(args)
				vacuum_query = %(VACUUM #{REPORTS_TABLE}) # cleaning up deleted space and re sorting the table
				execute_redshift_query(vacuum_query).clear
			end

		end
	end
end