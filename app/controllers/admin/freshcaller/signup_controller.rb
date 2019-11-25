class Admin::Freshcaller::SignupController < Admin::AdminController
  include ::Freshcaller::Endpoints
  include ::Freshcaller::Util

  before_filter :validate_linking, :only => :link

  def create
    freshcaller_response = enable_freshcaller_feature
    redirect_to(admin_phone_path) && return if freshcaller_response.present? && freshcaller_response['freshcaller_account_id'].present?
    render_error(freshcaller_response)
  end

  def link
    freshcaller_response = freshcaller_request(linking_params, freshcaller_link_url, :put)
    return render json: freshcaller_response if freshcaller_response['error'].present?

    link_freshcaller(freshcaller_response) if freshcaller_response['freshcaller_account_id'].present?
    render json: { domain: freshcaller_response['account_domain'] }
  end

  private

    def render_error(freshcaller_response)
      error = I18n.t("freshcaller.admin.feature_request_content.#{error_cause(freshcaller_response)}").html_safe
      render :signup_error, locals: { error: error }
    end

    def error_cause(freshcaller_response)
      return 'domain_taken' if domain_already_taken?(freshcaller_response)
      return 'spam_email' if spam_request?(freshcaller_response)

      'error'
    end

    def domain_already_taken?(freshcaller_response)
      freshcaller_response.present? && freshcaller_response['errors'].present? && freshcaller_response['errors']['domain_taken'].present?
    end

    def validate_linking
      linking_user = current_account.users.find_by_email(params[:email])
      render json: { error: 'No Access to link Account' } unless privileged_user?(linking_user)
    end

    def spam_request?(freshcaller_response)
      freshcaller_response.present? && freshcaller_response['errors'].present? && freshcaller_response['errors']['spam_email']
    end
end
