module ActiveRecordLog
    def self.included(base)
      base.class_eval do
        alias_method_chain :execute, :log
      end
    end

    def execute_with_log(sql, name = nil)
      unless @config.include?(:not_a_shard) 
         @logger.debug sql if sql.downcase.include?("select") and !sql.downcase.include?("shard_mappings") and !sql.downcase.include?("domain_mappings")
      end
      @connection.query(sql) 
      rescue ActiveRecord::StatementInvalid => exception
        if exception.message.split(":").first =~ /Packets out of order/
          raise ActiveRecord::StatementInvalid, "'Packets out of order' error was received from the database. Please update your mysql bindings (gem install mysql) and read http://dev.mysql.com/doc/mysql/en/password-hashing.html for more information.  If you're on Windows, use the Instant Rails installer to get the updated mysql bindings."
        else
          raise
        end
    end

end

ActiveRecord::ConnectionAdapters::MysqlAdapter.class_eval { include ActiveRecordLog }
