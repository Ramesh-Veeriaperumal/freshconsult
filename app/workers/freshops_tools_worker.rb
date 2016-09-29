class FreshopsToolsWorker < BaseWorker
  
  include Sidekiq::Worker
  include FreshopsToolsWorkerMethods

# The method name is passed as a parameter to call that corresponding method.
  def perform(args)
    if SHARD_OPS.has_value?(args["method_name"])
      operation_on_shard(args)
    else
      # To call the worker method which dynamically executes the rubyscript
      #send args["method_name"],args
    end
  end
  
end