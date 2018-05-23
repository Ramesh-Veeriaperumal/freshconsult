class RakeTaskController < ApiApplicationController

  before_filter :check_privilege

  def run_rake_task
    args = {
      task: params[:task],
      additional_params: params[:additional_params]
    }
    RunRakeTask.perform_async(args)
  rescue Exception => e
    Rails.logger.debug "exception while running rake task through api #{e}"
  end

  private

  def check_privilege
    return false if Rails.env.production?
    success = super
    render_request_error(:access_denied, 403) if success && User.current && !User.current.privilege?(:manage_account)
  end
end
