module HelpdeskAccessMethods
	def accessible_elements(items,filter_query_hash)
    Sharding.run_on_slave do
			items.find(:all, filter_query_hash).uniq
		end
	end

  def query_hash(model, table, conditions, includes = [], size = Helpdesk::Access::DEFAULT_ACCESS_LIMIT, access_type = nil)
    {
      select: ['*'],
      joins: "INNER JOIN (#{access_type_scope(access_type, model)}) as visible_elements ON
                  visible_elements.accessible_id = #{table}.id",
      conditions: conditions, include: includes, limit: size
    }
  end

  def access_type_scope(access_type, model)
    scoper_method = access_type.nil? ? 'all_user_accessible_sql' : "#{Helpdesk::Access::ACCESS_TYPES_KEYS[access_type]}_accessible_sql"
    Account.current.accesses.safe_send(scoper_method, model, User.current)
  end
end
