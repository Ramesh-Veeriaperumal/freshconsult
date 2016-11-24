module FreshopsToolsWorkerMethods

    SHARD_OPS ={:add => "add_to_shard" , :remove => "remove_from_shard"} 

# Accepts the key(file name ) and bucket name as arguments and executes the code in that file
  def dynamic_rubyscript_evaluation(args)
    # To fetch the code contained in the specific file from the specified bucket
    data = AwsWrapper::S3Object.read(args["path"],args["bucket_name"],{:content_type => "application/json"})
    key_path = args["path"].split('.').first + "_log.txt" # Name the execution log file
    code_id = args["path"].split('/').tap(&:pop).last
    begin
      output = capture(:stdout) do
        eval data
      end
      AwsWrapper::S3Object.store(key_path,output,args["bucket_name"])
      request_parameters = {:id => code_id ,:result => "Code Executed"}
      response = Fdadmin::APICallsToInternalTools.make_api_request_to_internal_tools(:get,request_parameters,:api_path,API_CONFIG_TOOLS[:domain])
    rescue Exception => e
      output = e.to_s + e.backtrace.to_s
      AwsWrapper::S3Object.store(key_path,output,args["bucket_name"])
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