# module ActiveRecordLog
#     def self.included(base)
#       base.class_eval do
#         alias_method_chain :execute, :log
#       end
#     end

#     def execute_with_log(sql, name = nil)
#       if @config.include?(:not_a_shard) or Rails.env.development?
#          @logger.debug sql if sql.downcase.include?("select") and !sql.downcase.include?("shard_mappings") and !sql.downcase.include?("domain_mappings")
#       end
#       @connection.query(sql) 
#       rescue ActiveRecord::StatementInvalid => exception
#         if exception.message.split(":").first =~ /Packets out of order/
#           raise ActiveRecord::StatementInvalid, "'Packets out of order' error was received from the database. Please update your mysql bindings (gem install mysql) and read http://dev.mysql.com/doc/mysql/en/password-hashing.html for more information.  If you're on Windows, use the Instant Rails installer to get the updated mysql bindings."
#         else
#           raise
#         end
#     end

# end

# ActiveRecord::ConnectionAdapters::MysqlAdapter.class_eval { include ActiveRecordLog }
module ActiveRecord
  class LogSubscriber
    include Cache::LocalCache
    include ActiverecordLogConstants
    def log_sql_statement(payload, event)
      # overriden the methos to hide the confidential logs
      # original code starts
      name  = "#{payload[:name]} (#{event.duration.round(1)}ms)"
      sql   = payload[:sql]
      binds = nil
      # original code ends
      # hiding confidential code starts
      begin
        if fetch_lcached_set(ACTIVE_RECORD_LOG, 2.minutes).present?
          if Account.current.nil? || Account.current.hiding_confidential_logs_enabled?
            sql = hide_confidential_logs(sql)
          end
          sql ||= payload[:sql]
        end
      rescue StandardError => e
        error "Exception in hiding confidential logs: #{e.inspect} sql: #{sql}"
        sql = payload[:sql]
      end
      # hiding confidential code ends
      # original code starts
      unless (payload[:binds] || []).empty?
        binds = '  ' + payload[:binds].map { |col, v| render_bind(col, v) }.inspect
      end

      if odd?
        name = color(name, CYAN, true)
        sql  = color(sql, nil, true)
      else
        name = color(name, MAGENTA, true)
      end

      debug "  #{name}  #{sql}#{binds}"
      # original code ends
    end

    def hide_confidential_logs(sql)
      if sql.start_with?('UPDATE')
        splitted_arr = UpdateSQLParser.new.parse_update_sql_query(sql)
        if splitted_arr.compact.size == 3
          table_name, values, remaining_part = splitted_arr
          filtered_values = filtering_update_values(values, table_name)
          return reconstruct_update_sql_query(table_name, filtered_values, remaining_part)
        end
      end
      sql
    end

    def filtering_update_values(values, table_name)
      columns = COLUMN_MODEL_NAME_HASH[table_name.to_sym][:columns]
      columns.each do |col|
        values[col] = '[FILTERED]' if values[col]
      end
      values
    end

    def join_update_values(values)
      result = []
      values.each { |a| result << a.join(' = ') }
      result
    end

    def reconstruct_update_sql_query(table_name, filtered_values, remaining_part)
      "UPDATE `#{table_name}` SET #{join_update_values(filtered_values).join(', ')} WHERE #{remaining_part}"
    end
  end
end
