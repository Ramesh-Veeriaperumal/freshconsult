class Reports::Queries
	
		def initialize(time_options)
			@start_time, @end_time = time_options[:start_time], time_options[:end_time]
			@end_of_day_time = Time.zone.parse(@end_time).end_of_day
		end


		def stats_query(options = {})
	    query = %( select #{options[:select_cols]} from #{options[:table]} #{options[:joins]} )
	    query += %( where #{options[:conditions]} ) #unless options[:conditions].blank?
	    query += %( group by #{options[:group_by]} ) if options[:group_by]
	    query += %( order by #{options[:order_by]} ) if options[:order_by]
	    query += %( limit #{options[:limit]} ) if options[:limit]
	    query
	  end

end
