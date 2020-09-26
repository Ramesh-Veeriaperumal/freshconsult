module Freshfone::AcwUtil

  def trigger_acw_timer(call)
    account = call.account
    worker_params = { call_id: call.id, account_id:
      account.id }
    timeout = account.freshfone_account.acw_timeout.minutes - 10.seconds
    job_id = Freshfone::AcwWorker.perform_in(timeout, worker_params,
                                             call.user_id)
    Rails.logger.info "Freshfone acw worker: Job-id: #{job_id}, Account ID: #{account.id}, User ID: #{call.user_id}, Worker Params: #{worker_params.inspect}"
  end

  def call_work_time_updated?(call)
    call_metrics_enabled?(call.account) &&
      !call.call_metrics.call_work_time.zero?
  end

  def update_call_work_time
    call = @freshfone_user.user.freshfone_calls.last
    call.update_acw_duration if call_metrics_enabled?(current_account)
  end

  private
    def agent_acw?
      @freshfone_user.acw?
    end

    def phone_acw_enabled?
      current_account.features? :freshfone_acw
    end

    def call_metrics_enabled?(account)
      account.features? :freshfone_call_metrics
    end
end
