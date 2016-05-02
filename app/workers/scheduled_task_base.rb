class ScheduledTaskBase < BaseWorker

  attr_accessor :task, :params, :retry_count

  # Abstract Implementation
  # Classes inheriting ScheduledTaskBase have to override execute_task(task) method to perform task related actions
  # return value
  # - false or error - failed execution
  def execute_task task
    true
  end

  def initialize_task(params)
    Account.reset_current_account
    self.params = params.symbolize_keys
    self.task = Helpdesk::ScheduledTask.find_by_id(self.params[:task_id]) if self.params[:task_id].is_a? Fixnum
  end

  #Never override, instead use execute_task!
  def perform(params)
    begin
      initialize_task(params)
      execute_on_account_scope { trigger_task_execution } if valid_task?
    rescue Exception => e
      NewRelic::Agent.notice_error(e, {:description => "Error on executing scheduled task #{params}"})
      logger.error "Error on executing scheduled task: #{task_printable}. Options :#{params.inspect}.\n#{e.message}\n#{e.backtrace.join("\n\t")}"
    ensure
      Account.reset_current_account
      User.reset_current_user
    end
  end

  def execute_on_account_scope
    return if task.account_id.blank?
    Sharding.select_shard_of(task.account_id) do
      Account.find(task.account_id).make_current
      yield
    end
  end

  def trigger_task_execution
    status = false
    begin
      task.user.make_current if task.user
      task.mark_in_progress.save!
      status = true if execute_task(task)
    rescue Exception => e
      raise
    ensure
      after_execute(status)
    end
  end

  def after_execute(exec_status)
    params[:retry_count] = params[:retry_count].to_i
    unless exec_status
      if params[:retry_count] < retry_count
        params[:retry_count] += 1
        task.mark_enqueued.save!
        task.worker.perform_in(5.minutes, params)
      else
        task.completed!(exec_status)
      end  
    end   
  end

  def retry_count
    self.retry_count || 0
  end

  def valid_task?
    task.present? && task.enqueued? && task.next_run_at.to_i == params[:next_run_at].to_i
  end

  def task_printable
    if task
      "account - #{task.account_id} :: task - " + task.as_json({}, false).to_s
    end
  end

end
