class Reports::ScheduledReports < ScheduledTaskBase

  sidekiq_options :queue => :scheduled_reports, :retry => 0, :backtrace => true, :failures => :exhausted

  include HelpdeskReports::Helper::PlanConstraints

  attr_accessor :task

  def execute_task task
    @task = task
    if task_permitted?
      Sharding.run_on_slave do
        logger.info "Calling Export on Scheduled Report #{task.id} : #{task.inspect}"
        HelpdeskReports::ScheduledReports::Worker.new(task).perform
      end
      return true
    else
      return :not_permitted
    end
  end

  def retry_count
  	2
  end

  private
    def task_permitted?
      result = false
      if !enable_schedule_report?
        task.mark_disabled.save!
      elsif (task.user.blocked? || !task.user.privilege?(:view_reports))
        AgentDestroyCleanup.perform_async({:user_id => task.user.id})
      else
        result = true
      end
      result
    end
end
