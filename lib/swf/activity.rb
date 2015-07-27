module Swf
  class Activity
                         
    attr_accessor :task, :name
    include Swf::ExceptionHandler

    def initialize(domain, name, identity)
      @domain   = domain
      @name     = name
      @identity = identity
    end
    
    def poll(&block)
      swf_sandbox do
        @task = $swf_client.poll_for_activity_task(
            domain: @domain,
            task_list: {
              name: @name
            },
            identity: @identity,
        )
        
        # If no task is available within 60 seconds, the poll will return an empty result. 
        # An empty result, in this context, means that an ActivityTask is returned, 
        # but that the value of taskToken is an empty string
        return if task.task_token.nil?
            
        yield if block_given?
      end
    end
    
    def activity_task_completed(results)
      swf_sandbox do 
        $swf_client.respond_activity_task_completed({
          task_token: task.task_token,
          result: results.to_json
        }) 
      end 
    end
    
    def activity_task_failed(reason, details)
      swf_sandbox do 
        $swf_client.respond_activity_task_failed({
          details: details,
          reason: reason,
          task_token: task.task_token
        })
      end
    end
    
    def workflow_name_from_task(task)
      swf_sandbox do 
        workflow_info = $swf_client.describe_workflow_execution(
          domain: @domain,
          execution: task.workflow_execution
        )
        workflow_info[:execution_info][:workflow_type][:name]
      end
    end
    
  end
end