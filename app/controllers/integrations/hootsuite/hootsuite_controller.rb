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
    @hootsuite_user ||= Integrations::HootsuiteRemoteUser.where(:remote_id => params[:uid]).first
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
        redirect_to params.merge(:controller => "home",:action => "domain_page")
      }
    end
  end

  def select_shard(&block)
    account_id = hootsuite_user.present? ? hootsuite_user.account_id : request.host
    Sharding.select_shard_of(account_id) do 
        yield 
    end
  end

  def current_account
    @current_account ||= hootsuite_current_account
  end

  def current_user
    @current_user ||= hootsuite_current_user
  end

  def hootsuite_current_account
    account = hootsuite_user.present? ? Account.find(hootsuite_user.account_id) : Account.fetch_by_full_domain(request.host)
    (raise ActiveRecord::RecordNotFound and return) unless account
    @current_portal = account.main_portal_from_cache
    @current_portal.make_current if @current_portal
    account
  end

  def hootsuite_current_user
    hootsuite_user.present? ? Account.current.users.find(hootsuite_user.configs[:freshdesk_user_id]) : nil
  end
end
  


  
