module FreshopsToolsWorkerMethods

    SHARD_OPS ={:add => "add_to_shard" , :remove => "remove_from_shard"} 

# Accepts the key(file name ) and bucket name as arguments and executes the code in that file
  def dynamic_rubyscript_evaluation(args)
    # To fetch the code contained in the specific file from the specified bucket
    data = AwsWrapper::S3Object.read(args["path"],args["bucket_name"],{:content_type => "application/json"})
    eval data # Evaluate the string directly
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