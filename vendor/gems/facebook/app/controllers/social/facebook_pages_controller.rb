class Social::FacebookPagesController < Admin::AdminController

  skip_before_filter :check_privilege, :verify_authenticity_token, :only => :event_listener
  before_filter { |c| c.requires_feature :facebook }

  #This Controller should be refactored
  before_filter :set_session_state , :only =>[:index, :edit, :update_page_token]
  before_filter :fb_client , :only => [:index, :edit, :update_page_token]
  before_filter :fb_client_page_tab , :only => [:index, :update_page_token]
  before_filter :add_page_tab, :only => [:edit, :update_page_token], :if => :facebook_page_tab?
  before_filter :load_item,  :only => [:edit, :update, :destroy]
  before_filter :load_tab, :only => [:edit, :destroy], :if => :facebook_page_tab?
  before_filter :handle_tab, :only => :update, :if => [:tab_edited?, :facebook_page_tab?]

  #This is for the callback function for facebook realtime app
  def index
    @fb_pages = enabled_facebook_pages
    if params[:code]
      begin
        @new_fb_pages = @fb_client.auth(params[:code])
      rescue Exception => e
        Rails.logger.error(e.inspect)
        Rails.logger.error(e.backtrace)
        flash[:error] = t('facebook.not_authorized')
      end
    end
  end

  #This is for callback function for facebook page_tab app
  def update_page_token
    @fb_pages = enabled_facebook_pages
    render "index"
  end

  def enable_pages
    pages = params[:enable][:pages]
    pages = pages.reject(&:blank?)
    add_to_db pages
    redirect_to :action => :index
  end

  def add_to_db fb_pages
    fb_pages.each do |fb_page|
      fb_page = ActiveSupport::JSON.decode fb_page
      fb_page.symbolize_keys!
      fb_page = fb_page.merge!({:enable_page =>true})
      begin
        page = scoper.find_by_page_id(fb_page[:page_id])
        unless page.blank?
          page_params = fb_page.tap { |fb| fb.delete(:fetch_since) }
          page.update_attributes(page_params)
        else
          page = scoper.new(fb_page)
          #remove the check
          page.save 
        end
      rescue Exception => e
        NewRelic::Agent.notice_error(e)
      end
    end
  end

  def destroy
    fb_page_tab.execute("remove") if @fb_tab
    @item.destroy
    flash[:notice] = t('facebook.deleted', :facebook_page => @item.page_name)
    redirect_to :action => :index
  end

  def update
    if @item.update_attributes(params[:social_facebook_page])
      flash[:notice] = I18n.t(:'flash.facebook.updated')
    else
      update_error
    end
    redirect_to :action => :index
  end

  protected

  def enabled_facebook_pages
    page_hash = {}
    page_token_tab = true
    scoper.each do |facebook_page|
      if page_hash[facebook_page.profile_id.to_s]
        page_hash[facebook_page.profile_id.to_s]["facebook_pages"] << facebook_page
        page_hash[facebook_page.profile_id.to_s]["tab"] ||= facebook_page.existing_page_tab_user?
      else
        page_hash[facebook_page.profile_id.to_s] = {}
        page_hash[facebook_page.profile_id.to_s]["facebook_pages"] = [facebook_page]
        page_hash[facebook_page.profile_id.to_s]["feature"] = facebook_page_tab?
        page_hash[facebook_page.profile_id.to_s]["tab"] = facebook_page.existing_page_tab_user?
      end
    end
    page_hash
  end

  # Duplicate method
  def  add_page_tab
    if params[:code]
      begin
        @fb_client_tab.auth(params[:code])
        @edit_tab = true
      rescue Exception => e
        flash[:error] = t('facebook.not_authorized')
      end
    end
  end


  def scoper
    current_account.facebook_pages
  end

  def fb_client
    @fb_client = Facebook::Oauth::FbClient.new(nil,fb_call_back_url)
    @fb_client_tab = Facebook::Oauth::FbClient.new("page_tab",fb_call_back_url(params[:action]))
  end

  def fb_client_page_tab
    @fb_client_page_tab = Facebook::Oauth::FbClient.new("page_tab",fb_call_back_url("update_page_token"))
  end


  def load_item
    @item = current_account.facebook_pages.find(params[:id])
  end

  def load_tab
    @fb_tab = fb_page_tab.execute("get") unless @item.page_token_tab.blank?
  end

  def handle_tab
    fb_page_tab.execute("add") if params[:add_tab]
    flash[:error] = t('facebook_tab.no_contact') unless fb_page_tab.execute("update",params[:custom_name])
  end

  def fb_page_tab
    Facebook::PageTab::Configure.new(@item,"page_tab")
  end

  def tab_edited?
    params[:custom_name]
  end

  def facebook_page_tab?
    current_account.features?(:facebook_page_tab)
  end

  def fetch_fb_wall_posts fb_page 
    Resque.enqueue(Facebook::Worker::FacebookMessage ,{:account_id => fb_page.account_id, :fb_page_id => fb_page.id})
  end

  def fb_call_back_url(action="index") 
      url_for(:host => current_account.full_domain, :action => action)
  end

  def set_session_state
    session[:state] = Digest::MD5.hexdigest(Helpdesk::SECRET_3+ Time.now.to_f.to_s)
  end

end
