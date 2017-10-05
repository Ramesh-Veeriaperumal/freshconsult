class Admin::Freshcaller::SignupController < Admin::AdminController
  
  include ::Freshcaller::JwtAuthentication

	def index
    response_data = freshcaller_request(signup_params, "#{FreshcallerConfig['signup_domain']}/accounts", :post)
    @response = response_data.symbolize_keys!
    return activate_freshcaller if @response.present? && @response[:freshcaller_account_id].present?
    return render_domain_error if domain_already_taken?
    render :signup_error, :locals => {:error => I18n.t('freshcaller.admin.feature_request_content.error').html_safe }
  end

  private 

  def activate_freshcaller
    add_freshcaller_account 
    add_freshcaller_agent
    enable_freshcaller
    disable_freshfone if current_account.freshfone_enabled?
    redirect_to admin_phone_path
  end 

  def render_domain_error
    error = I18n.t('freshcaller.admin.feature_request_content.domain_taken').html_safe
    return render :signup_error, :locals => {:error => error} 
  end

  def add_freshcaller_account
    current_account.create_freshcaller_account(:freshcaller_account_id => @response[:freshcaller_account_id], 
      :domain => @response[:freshcaller_account_domain] )
  end

  def add_freshcaller_agent
    current_user.agent.create_freshcaller_agent(:agent => current_user.agent, 
	    :fc_enabled => true, :fc_user_id => @response[:agent]["id"])
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
    @response.present? && @response[:errors].present? && @response[:errors]["account_full_domain"].present?
  end

  def signup_params
    protocol = Rails.env.development? ? 'http://' : 'https://'
    {
      :signup => {
        :user_name => current_user.name,
        :user_email => current_user.email,
        :account_name => current_account.name,
        :account_domain => "#{FreshcallerConfig['domain_prefix']}#{current_account.domain}",
        :api => {
          :account_name => current_account.name,
          :account_id => current_account.id,
          :freshdesk_calls_url => "#{protocol}#{current_account.full_domain}/api/channel/freshcaller_calls"
        }
      }
    }
  end
end
