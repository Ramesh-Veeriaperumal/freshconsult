class Mobile::SettingsController < ApplicationController
  require 'openssl'
  include ApplicationHelper
  include Mobile::Constants
  include Freshid::ControllerMethods

  skip_before_filter :check_privilege, :verify_authenticity_token, :only => [:deliver_activation_instructions,:mobile_login]
  skip_before_filter :require_user, :only => :mobile_login

  skip_filter :select_shard, :only => :mobile_login
  before_filter :determine_pod , :only => :mobile_login
  skip_before_filter :unset_current_account, :set_current_account, :check_session_timeout, only: :mobile_login
  skip_before_filter :check_account_state, :only => :mobile_login
  skip_before_filter :set_time_zone, :check_day_pass_usage  , :only => :mobile_login
  skip_before_filter :set_locale, :force_utf8_params , :only => :mobile_login
  skip_before_filter :logging_details , :only => :mobile_login

	def index
		render :json => {:success => true , :notifications_url => MobileConfig['notifications_url'][Rails.env]}
	end

  # Return full_domain @params cname; @authetication SHA2
  def mobile_login
      # header json string  
      # {'id':'...','times':'...','app_version':'1.2.3','api_version':1,'mobile_type':1,'os_version':'1.1.1','domain_name':'something','device_desc':'moto-g'}
      result_code = MOBILE_API_RESULT_PARAM_FAILED
      sso_enabled = false
      google_signin_enabled = false
      facebook_signin_enabled = false
      sso_logout_url = ""
      full_domain = ""
      org_login_url = ""
      unless request.headers['Request-Id'].nil?
        request_data = JSON.parse(request.headers['Request-Id'])
        sha_generated = OpenSSL::HMAC.hexdigest('sha512',MobileConfig['secret_key'],request_data['times'])
        
        if sha_generated == request_data['id'] 
          domain_mapping = ShardMapping.lookup_with_domain(params[:cname])
          unless domain_mapping.nil? 
            if (domain_mapping.pod_info == PodConfig['CURRENT_POD'])
              Sharding.select_shard_of(domain_mapping.account_id) do
                Sharding.run_on_slave do
                  account = Account.find(domain_mapping.account_id)
                  unless account.nil?
                    account.make_current
                    full_domain = account.full_domain
                    sso_enabled = account.sso_enabled? 
                    sso_logout_url = account.sso_logout_url
                    google_signin_enabled = account.features_included?(:google_signin)
                    facebook_signin_enabled = account.features_included?(:facebook_signin)
                    org_login_url = freshid_v2_mobile_authorize_url(account, params[:scheme]) if account.freshid_org_v2_enabled?
                  end
                end
              end
            else
              request_parameters = {:account_id => domain_mapping.account_id , :target_method => :fetch_mobile_login_info}
              response = connect_main_pod(request_parameters,domain_mapping.pod_info)
              sso_enabled = response['account_id']['sso_enabled']
              sso_logout_url = response['account_id']['sso_logout_url']
              full_domain = response['account_id']['full_domain']
              google_signin_enabled = response['account_id']['google_signin_enabled']
              facebook_signin_enabled = response['account_id']['facebook_signin_enabled']
              org_login_url = response['account_id']['org_login_url']
            end
          end
          result_code = MOBILE_API_RESULT_SUCCESS  #Success
        else
          #Failure case 2 : sha mismatch
          result_code = MOBILE_API_RESULT_SHA_FAIL 
        end

      end 
    response = {
      sso_logout_url: sso_logout_url, sso_enabled: sso_enabled, full_domain: full_domain, result_code: result_code,
      google_signin_enabled: google_signin_enabled, facebook_signin_enabled: facebook_signin_enabled
    }
    response[:org_login_url] = org_login_url if org_login_url.present?
    render :json => response
  end

  def deliver_activation_instructions
   #Code Moved to accounts/new_signup_free , so that activation mail is sent without second get request.
   render :json => {result: true}

  end  
  
  # Deprecated - use mobile_configurations
  def configurations
    render :json => current_user.as_config_json.merge(current_account.as_config_json)
  end	

  def mobile_configurations
    features_list = current_account.features_list
    account_configs = {:add_watcher => features_list.include?(:add_watcher), :sla_management => features_list.include?(:sla_management),
                       :traffic_cop => features_list.include?(:traffic_cop)}
    render :json => { userdetail: current_user.as_config_json.merge(current_account.as_config_json), agent_collision_url: agent_collision_url, account_configs: account_configs, iris_notification_host: iris_notification_host }
  end

  def iris_notification_host
    IrisNotificationsConfig["collector_host"]
  end

  private
  def connect_main_pod(request_parameters,pod_info)
    Fdadmin::APICalls.make_api_request_to_global(
      :post,
      request_parameters,
      PodConfig['pod_paths']['pod_endpoint'],
    "#{AppConfig["freshops_subdomain"][pod_info]}.#{AppConfig['base_domain'][Rails.env]}")
  end

  def agent_collision_url
    if current_account.features?(:collision)
      NodeConfig['socket_host_new']
    end
  end 
end
