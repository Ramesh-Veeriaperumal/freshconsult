class Integrations::OnedriveController < ApplicationController 
  skip_before_filter :check_privilege
  skip_before_filter :set_current_account, :check_account_state, :set_time_zone,
                    :check_day_pass_usage, :set_locale, :only => [:callback]
  include Integrations::Onedrive::OnedriveUtil
  include Integrations::Onedrive::Constant

  def callback
    if params["code"]       
      begin
        load_origin_info_onedrive
        onedrive_response = get_access_token
        access_token =  CGI.escape(onedrive_response["access_token"])
        user_id = CGI.escape(onedrive_response[USER_ID])
        redirect_url = get_redirect_url( access_token, user_id)
        redirect_to redirect_url
      rescue Exception => e
        NewRelic::Agent.notice_error(e,{:custom_params => {:description => "Error occoured while authenticating Onedrive account"}})
        Rails.logger.error "#{e}"
        render :text => "#{t(:'integrations.onedrive.error')}"
      end
    elsif params["error"]
      render :text => "#{t(:'integrations.onedrive.denied_scope')}"
    else
      render :json => {:success => true}
    end
  end

  def onedrive_render_application 
    render :partial => "/integrations/onedrive/callback"
  end

  def onedrive_view
    res = create_web_url
    render :json => res
  end

  private

  def load_origin_info_onedrive 
    @portal_url = Rack::Utils.parse_nested_query(CGI.unescape(params["state"]))['appstate']
  end

  
  def get_redirect_url access_token, user_id
    redirect_url = "#{@portal_url}/integrations/onedrive/onedrive_render_application#access_token=%s&token_type=%s&expires_in=%s&scope=%s&state=%s&user_id=%s" % [access_token, ONEDRIVE_TOKEN_TYPE,ONEDRIVE_TOKEN_EXPIRES_IN, ERB::Util.url_encode(ONEDRIVE_SCOPE), CGI.escape(params[STATE]), user_id ]
    redirect_url.gsub!( COOKIE, URL )  
  end

end