module HelpdeskAccessMethods
	def accessible_elements(items,query_hash)
    Sharding.run_on_slave do
			items.find(:all, query_hash)
		end
	end

	def query_hash(model, table, conditions, includes = [])
    {
    	:select => ["*"], 
    	:joins 	=> "INNER JOIN (#{current_account.accesses.all_user_accessible_sql(model, current_user)}) as visible_elements ON 
    							visible_elements.accessible_id = #{table}.id AND visible_elements.account_id = #{table}.account_id", 
      :conditions => conditions, :include => includes
    }
  end  
end
