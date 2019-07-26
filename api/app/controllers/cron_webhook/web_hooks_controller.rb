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

  private

    def constants_class
      CronWebhooks::Constants.to_s.freeze
    end
end
