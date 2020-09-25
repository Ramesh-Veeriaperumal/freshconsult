class Channel::Freshcaller::AccountsController < ApiApplicationController
  include ::Freshcaller::JwtAuthentication
  skip_before_filter :check_privilege, :check_day_pass_usage_with_user_time_zone, :verify_authenticity_token
  before_filter :custom_authenticate_request

  def update
    if @item.update_attributes(cname_params)
      head 204
    else
      render_custom_errors
    end
  end

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
    @item = current_account.freshcaller_account
    log_and_render_404 unless @item
  end

  def validate_params
    cname_params.permit(*Channel::Freshcaller::AccountConstants::UPDATE_FIELDS, *ApiConstants::DEFAULT_PARAMS)
  end
end
