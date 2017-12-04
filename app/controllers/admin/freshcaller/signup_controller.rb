class Admin::Freshcaller::SignupController < Admin::AdminController
  
  include ::Freshcaller::Endpoints

  before_filter :validate_linking, :only => :link

	def create
    response_data = freshcaller_request(signup_params, "#{FreshcallerConfig['signup_domain']}/accounts", :post)
    @freshcaller_response = response_data.deep_symbolize_keys
    return activate_freshcaller if @freshcaller_response.present? && @freshcaller_response[:freshcaller_account_id].present?
    return render_domain_error if domain_already_taken?
    render :signup_error, :locals => {:error => I18n.t('freshcaller.admin.feature_request_content.error').html_safe }
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
      user = current_account.users.find_by_email(user_details[:email]) if user_details
      user.agent.create_freshcaller_agent(:agent_id => user.agent.id, 
                                          :fc_enabled => true, 
                                          :fc_user_id => user_details[:user_id]) if user && user.active?
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
    {
      :signup => {
        :user_name => current_user.name,
        :user_email => current_user.email,
        :account_name => current_account.name,
        :account_domain => "#{FreshcallerConfig['domain_prefix']}#{current_account.domain}",
        :api => {
          :account_name => current_account.name,
          :account_id => current_account.id,
          :freshdesk_calls_url => "#{protocol}#{current_account.full_domain}/api/channel/freshcaller_calls",
          :app => 'Freshdesk',
          :domain_url => "#{protocol}#{current_account.full_domain}",
          :access_token => current_user.single_access_token
        }
      }
    }
  end

  def linking_params
    params.merge(account_name: current_account.name, 
                 account_id: current_account.id, 
                 activation_required: false,
                 freshdesk_calls_url: "#{protocol}#{current_account.full_domain}/api/channel/freshcaller_calls",
                 domain_url: "#{protocol}#{current_account.full_domain}",
                 access_token: current_user.single_access_token)
  end

end
