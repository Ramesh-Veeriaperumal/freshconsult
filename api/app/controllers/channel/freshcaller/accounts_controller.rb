class Channel::Freshcaller::AccountsController < ApiApplicationController
  include ::Freshcaller::JwtAuthentication
  skip_before_filter :check_privilege, :check_day_pass_usage_with_user_time_zone, :verify_authenticity_token
  before_filter :custom_authenticate_request

  def destroy
    begin
      Freshcaller::AccountDeleteWorker.perform_async({account_id: current_account.id})
      head 204
    rescue Exception => e
      render_errors ({delete: "false"})
      Rails.logger.error "Error while deleting Freshcaller Integration :Channel::Freshcaller::AccountsController: \n
      Account ID : #{current_account.id} \n
      :\n#{e.backtrace.join('\n')}"

    end
  end

  private 

  def load_object 
    current_account
  end

end
