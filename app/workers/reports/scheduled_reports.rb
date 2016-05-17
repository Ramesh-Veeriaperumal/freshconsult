class Reports::ScheduledReports < ScheduledTaskBase

  sidekiq_options :queue => :scheduled_reports, :retry => 0, :backtrace => true, :failures => :exhausted

  include HelpdeskReports::Helper::PlanConstraints

  attr_accessor :task

  def execute_task task
    @task = task
    if task_permitted?
      Sharding.run_on_slave do
        HelpdeskReports::ScheduledReports::Worker.new(task).perform
      end
      return true
    else
      return "not_permitted"
    end
  end

  def retry_count
  	2
  end

  private
    def task_permitted?
      result = false
      Sharding.select_shard_of(task.account_id) do
        if !enable_schedule_report?
          task.mark_disabled.save!
        elsif (task.user.blocked? || !task.user.privilege?(:view_reports))
          AgentDestroyCleanup.perform_async({:user_id => task.user.id})
        else
          result = true
        end
      end
      result
    end
end
