class Tickets::Schedule < ScheduledTaskBase
  
  sidekiq_options :queue => :scheduled_ticket_export, :retry => 4, :failures => :exhausted

  attr_accessor :task, :params

  def execute_task task
    @task = task
    if task_permitted?
      ::Export::TicketSchedule.new({:task_id => task.id}).perform
      true
    else
      :not_permitted
    end
  end

  private

    def task_permitted?
      if !Account.current.scheduled_ticket_export_enabled?
        return false
      elsif task.user.blocked?
        task.mark_disabled.save!
        return false
      end
      true
    end
end