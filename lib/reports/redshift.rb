module Reports
	module Redshift

		def execute_redshift_query(query, read_conn = false)
			rs = read_conn ? $redshift_read : $redshift
			begin
				rs.reset unless rs.status == PG::CONNECTION_OK
				rs.exec(query)
			rescue Exception => e
				Rails.logger.info "Redshift connection lost unexpectedly. Trying again..."
				rs.reset
				rs.exec(query)
			end
		end

	end
end