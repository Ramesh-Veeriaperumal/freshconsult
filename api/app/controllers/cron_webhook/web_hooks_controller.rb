class CronWebhook::WebHooksController < ApiApplicationController
  include CronWebhooks::Constants
  include CronWebhooks::CronHelper
  include HelperConcern
  include Redis::Semaphore

  skip_before_filter :check_privilege, :load_object

  def trigger
    return unless validate_body_params(nil, params)

    class_name = TASK_MAPPING[params[:task_name].to_sym][:class_name]
    key = get_semaphore_key(params, CONTROLLER)
    return render_request_error :semaphore_exists, 409 if semaphore_exists?(key)

    set_semaphore(key, 1, CONTROLLER_SEMAPHORE_EXPIRY)
    class_for_task = class_name.constantize
    Rails.logger.info "Enqueing started: #{class_name}" if dry_run_mode?(params[:mode])
    @jid = class_for_task.perform_async(params.slice(*WORKER_ARGS_KEYS))
    Rails.logger.info "Enqueing done: #{class_name}" if dry_run_mode?(params[:mode])
  end

  def trigger_cron_api
    return render_request_error :missing_params, 400 if params['account_type'].blank? || params['name'].blank?
    emptytask = {}
    name = params['name']
    automation = case name
                 when 'supervisor'
                   SUPERVISOR_TASKS
                 when 'sla_reminder'
                   SLA_REMINDER_TASKS
                 when 'sla_escalation'
                   SLA_TASKS
                 else
                   emptytask
                 end
    account_type = params['account_type']

    class_name = automation[account_type][:class_name] unless automation[account_type].nil?
    class_constant = class_name.constantize unless class_name.nil?
    return render_request_error :missing_params, 400 if class_constant.nil?

    @jobid = class_constant.perform_async unless class_constant.nil?
    Rails.logger.info "Jobid generated trigger_cron_api action: #{@jobid}"
  end

  private

    def constants_class
      CronWebhooks::Constants.to_s.freeze
    end
end
