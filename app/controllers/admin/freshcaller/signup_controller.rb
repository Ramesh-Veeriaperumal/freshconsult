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
  end

  private

    def link_freshcaller(freshcaller_response)
      freshcaller_activation_actions(freshcaller_response)
      link_freshcaller_agents(freshcaller_response)
      render json: { domain: freshcaller_response['account_domain'] }
    end

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

    def link_freshcaller_agents(freshcaller_response)
      freshcaller_response['user_details'].each do |user_details|
        next if user_details.nil?

        user_details_hash = user_details.with_indifferent_access
        user = current_account.users.find_by_email(user_details_hash['email']) if user_details_hash
        user.agent.create_freshcaller_agent(agent_id: user.agent.id, fc_enabled: true, fc_user_id: user_details_hash['user_id']) if user && user.active?
      end
    end

    def validate_linking
      linking_user = current_account.users.find_by_email(params[:email])
      render json: { error: 'No Access to link Account' } unless privileged_user?(linking_user)
    end

    def privileged_user?(user)
      (user.privilege?(:manage_account) || user.privilege?(:admin_tasks)) && user.active? if user
    end

    def spam_request?(freshcaller_response)
      freshcaller_response.present? && freshcaller_response['errors'].present? && freshcaller_response['errors']['spam_email']
    end

    def linking_params
      link_params = params.merge(account_name: current_account.name,
                                 account_id: current_account.id,
                                 activation_required: false,
                                 app: 'Freshdesk',
                                 freshdesk_calls_url: "#{protocol}#{current_account.full_domain}/api/channel/freshcaller_calls",
                                 domain_url: "#{protocol}#{current_account.full_domain}",
                                 access_token: current_user.single_access_token,
                                 account_region: ShardMapping.fetch_by_account_id(current_account.id).region)
      link_params.merge!(freshid_v2_params) if current_account.freshid_org_v2_enabled?
      link_params
    end
end
