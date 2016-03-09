class Integrations::Hootsuite::HootsuiteController < ApplicationController

  before_filter :authenticate_hootsuite_user

  layout false

  protected

  def authenticate_hootsuite_user
    if (params[:uid].nil? || params[:ts].nil? || params[:token].nil? || (Digest::SHA512.hexdigest(params[:uid] + params[:ts] + ThirdPartyAppConfig["hootsuite"]["shared_secret"]) != params[:token]))
         render :text =>  t("integrations.hootsuite.auth_error") and return
    end
  end

  def hootsuite_user
    Integrations::HootsuiteRemoteUser.where(:remote_id => params[:uid]).first
  end

  def hs_ticket_fields
    current_account.main_portal.ticket_fields(:default_fields).select {|f| (["requester","subject","description"].exclude?(f.name))}
  end

  def redirect_back_or_default(default)
    redirect_to(session[:hootsuite_return_to] || default)
    session[:hootsuite_return_to] = nil
  end

  def access_denied
    render 'integrations/hootsuite/home/agent_error' and return if @current_user.present? && !@current_user.agent?
    session[:hootsuite_return_to] = request.fullpath
    respond_to do |format|
      format.html {
        redirect_to params.merge(:controller => "home",:action => "hootsuite_login")
      }
    end
 end 
end
  


  