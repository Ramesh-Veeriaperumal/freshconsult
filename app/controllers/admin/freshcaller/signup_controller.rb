class Admin::Freshcaller::SignupController < Admin::AdminController
  
  include ::Freshcaller::Endpoints

  before_filter :validate_linking, :only => :link

	def create
    response_data = freshcaller_request(signup_params, "#{FreshcallerConfig['signup_domain']}/accounts", :post)
    @freshcaller_response = response_data.deep_symbolize_keys
    return activate_freshcaller if @freshcaller_response.present? && @freshcaller_response[:freshcaller_account_id].present?
    render_error
  end

  def link
    response_data = freshcaller_request(linking_params, freshcaller_link_url, :put) 
    @freshcaller_response = response_data.deep_symbolize_keys
    return render json: @freshcaller_response if @freshcaller_response[:error].present?
    link_freshcaller if @freshcaller_response[:freshcaller_account_id].present?
  end

  private 

  def activate_freshcaller
    freshcaller_activation_actions
    add_freshcaller_agent
    redirect_to admin_phone_path
  end

  def link_freshcaller
    freshcaller_activation_actions
    link_freshcaller_agents
    render json: { domain: @freshcaller_response[:account_domain] }
  end

  def freshcaller_activation_actions
    add_freshcaller_account
    enable_freshcaller
    disable_freshfone if current_account.freshfone_enabled?
  end


  def render_error
    error = I18n.t("freshcaller.admin.feature_request_content.#{error_cause}").html_safe
    render :signup_error, locals: { error: error } 
  end

  def error_cause
    return 'domain_taken' if domain_already_taken?
    return 'spam_email' if spam_request?
    'error'
  end

  def add_freshcaller_account
    current_account.create_freshcaller_account(:freshcaller_account_id => @freshcaller_response[:freshcaller_account_id], 
      :domain => @freshcaller_response[:freshcaller_account_domain])
  end

  def add_freshcaller_agent
    current_user.agent.create_freshcaller_agent(:agent => current_user.agent, 
	    :fc_enabled => true, :fc_user_id => @freshcaller_response[:user][:id])
  end

  def enable_freshcaller
    current_account.add_feature(:freshcaller)
    current_account.add_feature(:freshcaller_widget)
  end

  def disable_freshfone
    Rails.logger.debug "Freshfone :: Freshcaller :: Suspending freshfone account after creating freshcaller account"
    current_account.freshfone_account.suspend
    current_account.features.freshfone.destroy 
  end

  def domain_already_taken?
    @freshcaller_response.present? && @freshcaller_response[:errors].present? && @freshcaller_response[:errors][:domain_taken].present?
  end

  def link_freshcaller_agents
    @freshcaller_response[:user_details].each do |user_details|
      next if user_details.nil?
      user_details_hash = user_details.with_indifferent_access
      user = current_account.users.find_by_email(user_details_hash[:email]) if user_details_hash
      user.agent.create_freshcaller_agent(:agent_id => user.agent.id, 
                                          :fc_enabled => true, 
                                          :fc_user_id => user_details_hash[:user_id]) if user && user.active?
    end
  end

  def validate_linking
    linking_user = current_account.users.find_by_email(params[:email])
    render json: { error: 'No Access to link Account'} unless privileged_user?(linking_user)
  end

  def privileged_user?(user)
    ( user.privilege?(:manage_account) || user.privilege?(:admin_tasks) ) && user.active? if user
  end

  def spam_request?
    @freshcaller_response.present? && @freshcaller_response[:errors].present? && @freshcaller_response[:errors][:spam_email]
  end

  def signup_params
    create_new_account_params = {
      signup: {
        user_name: current_user.name,
        user_email: current_user.email,
        user_phone: current_user.phone.present? ? current_user.phone : current_user.mobile,
        account_name: current_account.name,
        time_zone: current_account.conversion_metric.try(:offset).to_s,
        account_domain: "#{FreshcallerConfig['domain_prefix']}#{current_account.domain}",
        account_region: ShardMapping.fetch_by_account_id(current_account.id).region,
        currency: current_account.subscription.try(:currency).try(:name),
        api: {
          account_name: current_account.name,
          account_id: current_account.id,
          freshdesk_calls_url: "#{protocol}#{current_account.full_domain}/api/channel/freshcaller_calls",
          app: 'Freshdesk',
          client_ip: request.remote_ip,
          domain_url: "#{protocol}#{current_account.full_domain}",
          access_token: current_user.single_access_token
        }
      }.merge(plan_name: Subscription::FRESHCALLER_PLAN_MAPPING[current_account.plan_name])
        .reject { |_key, val| val.nil? },
        session_json: current_account.conversion_metric.try(:session_json),
        source: 'Freshdesk',
        medium: 'in-product',
        country: current_account.conversion_metric.try(:country),
        first_referrer: "#{protocol}#{current_account.full_domain}"
      }
    create_new_account_params.merge!(freshid_v2_params(true)) if current_account.freshid_org_v2_enabled?
    create_new_account_params
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

  def freshid_v2_params(create_new_account = false)
    freshid_params = {
      fresh_id_version: Freshid::V2::Constants::FRESHID_SIGNUP_VERSION_V2,
      organisation_domain: current_account.organisation_domain
    }
    freshid_params[:join_token] = Freshid::V2::Models::Organisation.join_token if create_new_account
    freshid_params
  end
end
