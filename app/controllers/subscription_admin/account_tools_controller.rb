class SubscriptionAdmin::AccountToolsController < ApplicationController
	include ModelControllerMethods
  include AdminControllerMethods
  include Redis::RedisKeys
	include Redis::ReportsRedis
  include Cache::Memcache::GlobalBlacklistIp

  before_filter :set_selected_tab , :load_global_blacklisted_ips 

  def index
    @blacklisted_ip_pagination = blacklisted_ips.ip_list.paginate( :page => params[:page], :per_page => 5) if blacklisted_ips.ip_list
  end

  def regenerate_reports_data
  	# return if params[:account_id].nil? || params[:start_date].nil? || params[:end_date].nil?
		
		(params[:start_date].to_date).upto(params[:end_date].to_date) do |day|
			add_to_reports_set(REPORT_STATS_REGENERATE_KEY % {:account_id => params[:account_id]}, day)
		end

    respond_to do |format|
      format.json { render :json => 'success' }
    end
  end

  def update_global_blacklist_ips
    @item = GlobalBlacklistedIp.first
    @item.ip_list = Array.wrap(params["ip_list"])
    if @item.save
      flash[:notice] = "Global Blacklist IP's updated"
      redirect_to :action => 'index'
    else
      flash[:notice] = "Update failed"
      redirect_to :action => 'index'
    end
  end

  def load_global_blacklisted_ips
    @blacklisted_ips = blacklisted_ips
  end

  protected
    def set_selected_tab
       @selected_tab = :tools
    end  

    def check_admin_user_privilege
      if !(current_user and current_user.has_role?(:tools))
        flash[:notice] = "You dont have access to view this page"
        redirect_to(admin_subscription_login_path)
      end
    end 
end