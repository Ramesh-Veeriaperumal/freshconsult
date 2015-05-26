class Mobile::SettingsController < ApplicationController
  require 'openssl'
  include ApplicationHelper
  include Mobile::Constants

  skip_before_filter :check_privilege, :verify_authenticity_token, :only => [:deliver_activation_instructions,:mobile_login]
  skip_before_filter :require_user, :only => :mobile_login

	def index
		render :json => {:success => true , :notifications_url => MobileConfig['notifications_url'][Rails.env]}
	end

  # Return full_domain @params cname; @authetication SHA2
  def mobile_login
      # header json string  
      # {'id':'...','times':'...','app_version':'1.2.3','api_version':1,'mobile_type':1,'os_version':'1.1.1','domain_name':'something','device_desc':'moto-g'}
      result_code = MOBILE_API_RESULT_PARAM_FAILED
      unless request.headers['Request-Id'].nil?
        request_data = JSON.parse(request.headers['Request-Id'])

        mobile_app_detail = MobileAppVersion.mobile_app(request_data['app_version'],request_data['mobile_type']).first

        unless mobile_app_detail.nil?
          sha_generated = OpenSSL::HMAC.hexdigest('sha512',MobileConfig['secret_key'],request_data['times'])

          if sha_generated == request_data['id']  && mobile_app_detail.supported
            full_domain = DomainMapping.full_domain(params[:cname]).first
            full_domain = full_domain.domain unless full_domain.nil?
            result_code = MOBILE_API_RESULT_SUCCESS  #Success
          elsif !mobile_app_detail.supported
            #Failure case 1 : version needs upgrade
            result_code = MOBILE_API_RESULT_UNSUPPORTED
          else
            #Failure case 2 : sha mismatch
            result_code = MOBILE_API_RESULT_SHA_FAIL 
          end
        end
      end 

    render :json => {full_domain: full_domain,result_code: result_code}
  end

# Mobile devices to fetch admin level settings
  def mobile_pre_loader
    render :json => {ff_feature: current_account.freshfone_account, view_social: can_view_social? && handles_associated? , portal_name: current_account.portal_name, portal_id: current_account.id, host_name: current_account.host, user_id: current_user.id }
  end

  def deliver_activation_instructions

   #Code Moved to accounts/new_signup_free , so that activation mail is sent without second get request.

   render :json => {result: true}

  end  
   
  def configurations
    render :json => {:user => current_user.as_config_json, :account => current_account.as_config_json }
  end	

end
