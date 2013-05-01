module Workers
	module DeleteArchivedData
		@queue = "delete_archived_reports_data"

		class << self

			include Reports::Constants
			include Reports::Redshift

			def perform(args)
				args.symbolize_keys!
				account_id = args[:account_id]
				query = %(DELETE from #{REPORTS_TABLE} where account_id = #{account_id})
				execute_redshift_query(query).clear
			end

		end

	end
end