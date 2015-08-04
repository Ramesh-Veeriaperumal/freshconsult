module Swf
  class Workflow
    
    attr_accessor :task, :server_identity
    include Swf::ExceptionHandler
    
    def initialize(domain, workflow, server_identity)
      @domain            = domain
      @name              = workflow[:name]
      @version           = workflow[:version]
      @id                = workflow[:id]
      @task_list         = workflow[:default_task_list][:name]
      @task_timeout      = workflow[:default_task_start_to_close_timeout]
      @execution_timeout = workflow[:default_execution_start_to_close_timeout]
      @server_identity   = server_identity
    end

    # Can override the timeout specified while
    # workflow was registered
    def start_workflow(data, tags =[])
      swf_sandbox do
        $swf_client.start_workflow_execution(
          domain: @domain,
          workflow_id: @id,
          workflow_type: {
            name: @name,
            version: @version,
          },
          task_start_to_close_timeout: @task_timeout ,  
          execution_start_to_close_timeout: @execution_timeout,
          task_list: {
            name: @task_list
          },
          input: data,
          tag_list: tags,
          child_policy: "ABANDON"
        )
      end
    end
    
    def decide(&block)
      swf_sandbox do
        @task = $swf_client.poll_for_decision_task(
            domain: @domain, 
            task_list: { name: @task_list }
        )
        return unless task.events
        yield if block_given?
      end
    end

    protected

    def schedule_activity(token, activity, input)
      swf_sandbox do
        $swf_client.respond_decision_task_completed(
          task_token: token,
          decisions: [
            schedule_activity_hash(activity, input)
          ],
          execution_context: server_identity
        )
      end    
    end

    def complete_workflow(token, result)
      swf_sandbox do
        $swf_client.respond_decision_task_completed(
          task_token: token,
          decisions: [
            {
              decision_type: "CompleteWorkflowExecution",
              complete_workflow_execution_decision_attributes: {
                result: result,
              }
            }
          ],
          execution_context: server_identity
        )
      end
    end

    def fail_workflow_execution(token, reason, data)
      swf_sandbox do 
        $swf_client.respond_decision_task_completed(
          task_token: token,
          decisions: [
            {
              decision_type: "FailWorkflowExecution",
              fail_workflow_execution_decision_attributes: {
                reason: reason,
                details: data,
              },
            }
          ],
          execution_context: server_identity
        )
      end
    end

    # Overriding the timeout values that were specified 
    # while registering the activity
    def schedule_activity_hash(activity, input)
      {
        decision_type: "ScheduleActivityTask",
        schedule_activity_task_decision_attributes: {
          activity_id: generate_id(activity[:name]),
          activity_type: {
            name: activity[:name],
            version: activity[:version],
          },
          #control: "Control Data",
          input: input,
          heartbeat_timeout: activity[:default_task_heartbeat_timeout],
          schedule_to_close_timeout: activity[:default_task_schedule_to_start_timeout],
          schedule_to_start_timeout: activity[:default_task_schedule_to_close_timeout],
          start_to_close_timeout: activity[:default_task_start_to_close_timeout],
          task_list: {
            name: activity[:default_task_list][:name]
          }
        }  
      }
    end    

    def generate_id(name)
      "#{name.downcase}_#{Time.now.utc.strftime("%Y-%m-%d %H:%M")}"
    end
  end
end