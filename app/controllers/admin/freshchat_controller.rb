class Admin::FreshchatController < Admin::AdminController
  include Freshchat::Util

  before_filter :load_item, :load_profile
  before_filter :load_plan, only: [:index]

  def create
    flash[:notice] = I18n.t('failure_msg') unless create_item
    render :index
  end

  def signup
    freshchat_response = signup_freshchat_account
    Rails.logger.info "Freshchat Response :: #{freshchat_response.body} #{freshchat_response.code} #{freshchat_response.message} #{freshchat_response.headers.inspect}"
    if freshchat_response.code == 200
      return render_error(freshchat_response) if freshchat_response.try(:[], 'errorCode').present?

      freshchat_app_id = freshchat_response['userInfoList'][0]['appId']
      freshchat_app_key = freshchat_response['userInfoList'][0]['appKey']
      if freshchat_response.present? && freshchat_app_id.present? && freshchat_app_key.present?
        Freshchat::Account.create(app_id: freshchat_app_id, portal_widget_enabled: false, token: freshchat_app_key, enabled: true)
        redirect_to :action => 'index'
      else
        Rails.logger.error "Freshchat Appid or key missing appid: #{freshchat_app_id} key: #{freshchat_app_key}"
        render_error({})
      end
    else
      Rails.logger.error "Freshchat returned a non 200 response"
      render_error({})
    end
  end

  def update
    flash[:notice] = I18n.t('failure_msg') unless update_item
    render :index
  end

  def toggle
    render :json => update_item
  end

  private

  def load_item
    @item = current_account.freshchat_account || Freshchat::Account.new
  end

  def load_plan
    @is_2019_plan = SubscriptionPlan::JAN_2019_PLAN_NAMES.include? current_account.subscription.plan_name
  end

  def load_profile
    @profile = current_user.agent
  end

  def update_item
    # params[:freshchat_account][:preferences] = @item.preferences.merge(params[:freshchat_account][:preferences]) if params[:freshchat_account][:preferences]
    @item.update_attributes(permitted_params)
  end

  def create_item
    @item = Freshchat::Account.create(permitted_params)
  end

  def permitted_params
    params[:freshchat_account].permit(:app_id, :enabled, :portal_widget_enabled, :token)
  end

  def render_error(freshchat_response)
      error = I18n.t("freshchat.admin.error.#{error_cause(freshchat_response)}").html_safe
      render :signup_error, locals: {error: error}
  end

  def error_cause(freshchat_response)
    return 'unable_to_reach_freshchat' if freshchat_response.blank?
    return 'already_logged_in' if freshchat_response["errorCode"] == 'ERR_ALREADY_LOGGED_IN'
    return 'already_present' if freshchat_response["errorCode"] == 'ERR_LOGIN_TO_SIGNUP'
    'unable_to_reach_freshchat'
  end
end
