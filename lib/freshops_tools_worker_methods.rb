module FreshopsToolsWorkerMethods

    SHARD_OPS ={:add => "add_to_shard" , :remove => "remove_from_shard"} 
# Accepts the key(file name ) and bucket name as arguments and executes the code in that file
  def dynamic_rubyscript_evaluation(args)
    # To fetch the code contained in the specific file from the specified bucket
    s3 = Aws::S3::Client.new(region: 'us-east-1',access_key_id: S3_CONFIG[:access_key_id],secret_access_key: S3_CONFIG[:secret_access_key])
    data = s3.get_object(key: args["path"],bucket: args["bucket_name"]).body.read
    code_id = args["path"].split('_').last.split('.').first
    key_path = API_CONFIG_TOOLS[:code_console_file_path] + code_id +".txt" # Name the execution log file
    begin
      output = capture(:stdout) do
        eval data
      end
      s3.put_object(key: key_path,bucket: args["bucket_name"],body: output)
      request_parameters = {:id => code_id ,:result => "Code Executed"}
      response = Fdadmin::APICallsToInternalTools.make_api_request_to_internal_tools(:get,request_parameters,:api_path,API_CONFIG_TOOLS[:domain])
    rescue Exception => e
      output = e.to_s + e.backtrace.to_s
      s3.put_object(key: key_path,bucket: args["bucket_name"],body: output)
      request_parameters = {:id => code_id ,:result => "Execution Error"}
      response = Fdadmin::APICallsToInternalTools.make_api_request_to_internal_tools(:get,request_parameters,:api_path,API_CONFIG_TOOLS[:domain])
    end
  end


# Based on the method name , shard name (received as parameters) will execute the corresponding operation
  def operation_on_shard(args) 
    Sharding.run_on_shard(args["shards_name"].to_s) do 
      Sharding.run_on_slave do
        Account.find_in_batches(:batch_size => 500) do |accounts|
          accounts.each do |account|
            next unless account.active?
            Account.reset_current_account
            account.make_current
            if (args["method_name"] == SHARD_OPS[:add])
              $redis_others.sadd("SLAVE_QUERIES",account.id)
            elsif(args["method_name"] == SHARD_OPS[:remove])
              $redis_others.srem("SLAVE_QUERIES",account.id)
            end
          end
        end
      end
    end
  end
  
end