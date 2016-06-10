class Mobile::SettingsController < ApplicationController
  require 'openssl'
  include ApplicationHelper
  include Mobile::Constants

  skip_before_filter :check_privilege, :verify_authenticity_token, :only => [:deliver_activation_instructions,:mobile_login]
  skip_before_filter :require_user, :only => :mobile_login

  skip_filter :select_shard, :only => :mobile_login
  before_filter :determine_pod , :only => :mobile_login
  skip_before_filter :unset_current_account, :set_current_account , :only => :mobile_login
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
      sso_logout_url = ""
      full_domain = ""
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
                    full_domain = account.full_domain
                    sso_enabled = account.sso_enabled? 
                    sso_logout_url = account.sso_logout_url
                  end
                end
              end
            else
              request_parameters = {:account_id => domain_mapping.account_id , :target_method => :fetch_mobile_login_info}
              response = connect_main_pod(request_parameters,domain_mapping.pod_info)
              sso_enabled = response['account_id']['sso_enabled']
              sso_logout_url = response['account_id']['sso_logout_url']
              full_domain = response['account_id']['full_domain']
            end
          end
          result_code = MOBILE_API_RESULT_SUCCESS  #Success
        else
          #Failure case 2 : sha mismatch
          result_code = MOBILE_API_RESULT_SHA_FAIL 
        end

      end 
    render :json => {sso_logout_url: sso_logout_url,sso_enabled: sso_enabled,full_domain: full_domain,result_code: result_code}
  end

# Mobile devices to fetch admin level settings
# Deprecated - use configurations
  def mobile_pre_loader
    render :json => {ff_feature: current_account.freshfone_account, view_social: can_view_social? && handles_associated? , portal_name: current_account.portal_name, portal_id: current_account.id, host_name: current_account.host, user_id: current_user.id,ff_conference: current_account.features?(:freshfone_conference) }
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
    render :json => {userdetail: current_user.as_config_json.merge(current_account.as_config_json),ff_nodeurl: FreshfoneConfig['node_url'], agent_collision_url: agent_collision_url}
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
    current_account.features?(:collision)? NodeConfig["socket_host"] : nil
  end 
end
