class Reports::ScheduledReports < ScheduledTaskBase

  sidekiq_options :queue => :scheduled_reports, :retry => 0, :backtrace => true, :failures => :exhausted

  include HelpdeskReports::Helper::PlanConstraints

  def execute_task task
    
    task.mark_disabled && return unless enable_schedule_report?

    Sharding.run_on_slave do
      HelpdeskReports::ScheduledReports::Worker.new(task).perform
    end
  end

  def retry_count
  	2
  end

end
