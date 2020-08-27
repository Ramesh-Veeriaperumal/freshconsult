class Admin::SecurityController <  Admin::AdminController

  include Redis::RedisKeys
  include Redis::OthersRedis
  include FDPasswordPolicy::Constants

  before_filter :load_whitelisted_ips, :load_password_policies, :only => :index

  def index
    @account = current_account
    @portal = current_account.main_portal
    @custom_ssl_requested = get_others_redis_key(ssl_key).to_i
  end

  def update
    @account = current_account
    @account.sso_enabled = (@account.freshid_org_v2_enabled? && !@account.sso_enabled?) ? "0" : params[:account][:sso_enabled]
    @account.ssl_enabled = params[:account][:ssl_enabled] || @account.ssl_enabled
    new_account_configuration = @account.account_configuration.contact_info.dup
    new_account_configuration[:notification_emails] = params[:account][:account_configuration_attributes]
    @account.account_configuration.contact_info = new_account_configuration
    account_additional_settings = @account.account_additional_settings
    deny_iframe_enabled = !params[:account][:deny_iframe][:enabled].to_bool

    if current_account.features_included?(:whitelisted_ips)
      if params[:account][:whitelisted_ip_attributes][:enabled].to_bool
        @account.whitelisted_ip_attributes = params[:account][:whitelisted_ip_attributes]
        @whitelisted_ips = @account.whitelisted_ip
        @whitelisted_ips.load_ip_info(request.env['CLIENT_IP'])
      elsif @account.whitelisted_ip
        @account.whitelisted_ip.enabled = params[:account][:whitelisted_ip_attributes][:enabled]
      end
    end

    if params[:ssl_type].present?
      current_account.main_portal.update_attributes( :ssl_enabled => params[:ssl_type] )
    end
    freshid_saml_sso_disabled = true if @account.freshid_saml_sso_enabled? && params[:account].key?(:sso_options) && params[:account][:sso_options][:sso_type] != SsoUtil::SSO_TYPES[:freshid_saml]
    oauth2_sso_disabled = true if @account.oauth2_sso_enabled? && params[:account].key?(:sso_options) && params[:account][:sso_options][:sso_type] != SsoUtil::SSO_TYPES[:oauth2]
    if @account.sso_enabled?
      @account.sso_options = params[:account][:sso_options]
      @account.remove_oauth2_sso_options if oauth2_sso_disabled
      @account.remove_freshid_saml_sso_options if freshid_saml_sso_disabled
      sso_array = if @account.sso_options[:sso_type] == SsoUtil::SSO_TYPES[:oauth2]
                    [:agent_oauth2, :customer_oauth2]
                  elsif @account.sso_options[:sso_type] == SsoUtil::SSO_TYPES[:freshid_saml]
                    [:agent_freshid_saml, :customer_freshid_saml]
                  end
      sso_array.each do |key|
        @account.sso_options[key] = @account.sso_options[key].to_bool if @account.sso_options[key].present?
      end
    else
      if @account.freshid_sso_sync_enabled? && @account.freshid_sso_enabled?
        Rails.logger.info "freshid_sso_sync enabled so removing freshdesk sso options"
        @account.remove_freshdesk_sso_options
      else
        @account.reset_sso_options
      end
    end

    account_additional_settings.additional_settings[:security] = { deny_iframe_embedding: deny_iframe_enabled }
    set_password_policies if @account.custom_password_policy_enabled? && !@account.sso_enabled?
    if @account.save && @account.account_configuration.save
      flash[:notice] = t(:'flash.sso.update.success')
      redirect_to admin_home_index_path
    else
      @portal = current_account.main_portal
      @custom_ssl_requested = get_others_redis_key(ssl_key).to_i
      load_whitelisted_ips
      load_password_policies
      render :action => 'index'
    end
  end

  def ssl_key
    CUSTOM_SSL % { :account_id => current_account.id }
  end

  def request_custom_ssl
    if current_account.features?(:custom_ssl)
      set_others_redis_key(ssl_key, "1", 86400*10)
      current_account.main_portal.update_attributes( :portal_url => params[:domain_name] )
      FreshdeskErrorsMailer.error_email( nil, 
                                                { "domain_name" => params[:domain_name] }, 
                                                nil, 
                                                { :subject => "Request for new SSL Certificate -
                                                            Account ID ##{current_account.id}" })
      render :json => { :success => true }
    else
      render :json => { :success => false }
    end
  end

  def load_whitelisted_ips
		if current_account.features_included?(:whitelisted_ips)
			@whitelisted_ips = current_account.whitelisted_ip || current_account.build_whitelisted_ip
		end
  end

  private

    def set_password_policies
      if params[:password_policy]
        set_contact_policy
        set_agent_policy
      end
    end

    def set_contact_policy
      if(params[:contact_policy] != "none" and params[:password_policy][:contact])
        load_contact_policy
        @contact_policy.policies = params[:password_policy][:contact][:policies]
        @contact_policy.configs = params[:password_policy][:contact][:configs] || {}
      end
    end 

    def set_agent_policy
      if(params[:agent_policy] != "none" and params[:password_policy][:agent])
        load_agent_policy
        @agent_policy.policies = params[:password_policy][:agent][:policies]
        @agent_policy.configs = params[:password_policy][:agent][:configs] || {}
      end
    end

    def load_password_policies
      load_contact_policy
      load_agent_policy
    end

    def load_contact_policy
      @contact_policy = current_account.contact_password_policy || current_account.build_contact_password_policy
    end

    def load_agent_policy
       @agent_policy = current_account.agent_password_policy || current_account.build_agent_password_policy
    end

end
