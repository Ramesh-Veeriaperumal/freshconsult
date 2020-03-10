module HelpdeskAccessMethods
	def accessible_elements(items,filter_query_hash)
    Sharding.run_on_slave do
			items.find(:all, filter_query_hash).uniq
		end
	end

	def query_hash(model, table, conditions, includes = [], size = 300)
    {
    	:select => ["*"],
    	:joins 	=> "INNER JOIN (#{Account.current.accesses.all_user_accessible_sql(model, User.current )}) as visible_elements ON
    							visible_elements.accessible_id = #{table}.id",
      :conditions => conditions, :include => includes, :limit => size
    }
  end

end
