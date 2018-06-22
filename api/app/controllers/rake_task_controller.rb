class RakeTaskController < ApiApplicationController
  ALLOWED_TASKS = YAML::load_file(Rails.root.join('config', 'run_rake_task.yml'))[Rails.env]['allowed_tasks']
  before_filter :check_environment, :check_params, :validate_params

  def run_rake_task
    args = {
      task: params[:task],
      additional_params: params[:additional_params]
    }
    RunRakeTask.perform_async(args)
  rescue => exception
    Rails.logger.debug "exception while running rake task through api #{exception.inspect}"
  end

  private

    def check_environment
      render_request_error :unsupported_environment, 400 if Rails.env.production?
    end

    def check_params
      render_request_error :missing_params, 400 if params[:task].blank?
    end

    def validate_params
      render_request_error :access_denied, 403 if ALLOWED_TASKS.exclude?(params[:task])
    end
end
