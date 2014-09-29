module Reports
	module Workers
		module RunRedshiftTableVacuum
			@queue = "load_reports_data_to_redshift"

			class << self
	      include Reports::Constants
				include Reports::Redshift
				include Reports::ArchiveData

	      def perform(args)
	      	date = Time.now.utc
	      	begin
	      		execute_redshift_query("set wlm_query_slot_count to 2;")
						vacuum_query = full_vacuum?(date) ? %(VACUUM #{REPORTS_TABLE}) : %(VACUUM SORT ONLY #{REPORTS_TABLE})# cleaning up deleted space and re sorting the table
						execute_redshift_query(vacuum_query).clear
	      	rescue => e
						subject = "Error occured while running vacuum"
						message =  e.message << "\n" << e.backtrace.join("\n")
						report_notification(subject,message)
						raise e
					ensure
						execute_redshift_query("set wlm_query_slot_count to 1;")
	      	end	      	
				end

				def full_vacuum?(date)
					(date.sunday? || date.wednesday?)
				end
			end
		end
	end
end