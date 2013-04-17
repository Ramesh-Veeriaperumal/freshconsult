ThinkingSphinx::Source.class_eval do
    
    def set_source_database_settings(source)
      model_configurations =  @model.configurations
      db_slave_key = "#{RAILS_ENV}_shard_shard_1_slave"
      db_master_key = "#{RAILS_ENV}_shard_shard_1" 
      config = (model_configurations[db_slave_key]) || (model_configurations[db_master_key])
      config.symbolize_keys!
      source.sql_host = config[:host]           || "localhost"
      source.sql_user = config[:username]       || config[:user] || 'root'
      source.sql_pass = (config[:password].to_s || "").gsub('#', '\#')
      source.sql_db   = config[:database]
      source.sql_port = config[:port]
      source.sql_sock = config[:socket]
    end
end





