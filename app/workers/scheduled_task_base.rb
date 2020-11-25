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
  end

  #Never override, instead use execute_task!
  def perform(options)
    begin
      logger.info "Received ScheduledTask with #{options.inspect} for execution."
      HelpdeskReports::Logger.log("scheduled : account_id: #{options['account_id']}, task_id: #{options['task_id']}")
      initialize_task(options)
      #Account dependent tasks, Account independent tasks & rake invocations respectively
      if params[:account_id].present?
        execute_on_account_scope { trigger_task_execution if valid_task? }
      else
        execute_on_common_scope { trigger_task_execution if valid_task? }
      end
    rescue Exception => e
      NewRelic::Agent.notice_error(e, {:description => "Error on executing scheduled task #{params}"})
      message = "Error on executing scheduled task: #{task_printable}. Options :#{params.inspect}.\n#{e.message}\n#{e.backtrace.join("\n\t")}"
      logger.error "#{message}"
      # DevNotification.publish(SNS["reports_notification_topic"], "Error on executing scheduled task", message)
    ensure
      Account.reset_current_account
      User.reset_current_user
    end
  end

  def execute_on_account_scope
    return if params[:account_id].blank?
    begin
      Sharding.select_shard_of(params[:account_id]) do
        Account.find(params[:account_id]).make_current
        self.task = Helpdesk::ScheduledTask.find_by_id(params[:task_id]) if params[:task_id].is_a? Fixnum
        yield
      end
    rescue DomainNotReady => e
      Rails.logger.error "Ignoring DomainNotReady , #{e.inspect}, Params: #{params.inspect}"
    rescue ShardNotFound => e
      Rails.logger.error "Ignoring ShardNotFound, #{e.inspect}, Params: #{params.inspect}"
    rescue AccountBlocked => e
      Rails.logger.error "Ignore AccountBlocked, #{e.inspect}, Params: #{params.inspect}"
    rescue ActiveRecord::RecordNotFound => e
      Rails.logger.error "Ignore ActiveRecord::RecordNotFound, #{e.inspect}, Params: #{params.inspect}"
    end
  end

  def execute_on_common_scope
    return if params[:task_id].blank?
    self.task = Helpdesk::ScheduledTask.find_by_id(params[:task_id]) if params[:task_id].is_a? Fixnum
    yield if Helpdesk::ScheduledTask::ACCOUNT_INDEPENDENT_TASKS.include?(self.task.schedulable_name)
  end

  def trigger_task_execution
    logger.info "Triggering scheduled task execution : #{params.inspect}"
    status = false
    begin
      task.user.make_current if task.user
      task.mark_in_progress.save!
      status = execute_task(task)
    rescue Exception => e
      raise
    ensure
      logger.info "Scheduled task execution complete : #{params.inspect}. Status : #{status}"
      after_execute(status)
    end
  end

  def after_execute(exec_status)
    #For handling tasks created by users who no longer hold reports priveleges
    return if [:not_permitted, :delayed_processing].include?(exec_status)
    params[:retry_count] = params[:retry_count].to_i
    unless exec_status
      if params[:retry_count] < retry_count
        params[:retry_count] += 1
        task.mark_enqueued.save!
        task.worker.perform_in(5.minutes, params)
        return
      end  
    end
    if (exec_status || task.dead_task?)
      task.completed!(exec_status)
    else
      task.increment_consecutive_failuers
      task.save!
    end 
  end

  def retry_count
    self.retry_count || 0
  end

  def valid_task?
    task.present? && task.enqueued? && ((task.next_run_at.to_i == params[:next_run_at].to_i) || task.dead_task?)
  end

  def task_printable
    "account - #{task.account_id} :: task - " + task.as_json({}, false).to_s if task
  end

end
