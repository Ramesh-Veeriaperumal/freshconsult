class Social::FacebookPagesController < Admin::AdminController

  helper Admin::Social::UIHelper
  
  before_filter { access_denied unless current_account.basic_facebook_enabled? }

  #This Controller should be refactored
  before_filter :social_revamp_enabled?
  before_filter :set_session_state ,  :only => [:index, :edit, :update_page_token]
  before_filter :fb_client,           :only => [:index, :edit, :update_page_token]
  before_filter :load_item,           :only => [:edit, :update, :destroy]

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
          break unless current_account.add_new_facebook_page?
          page = scoper.new(fb_page)
          page.save 
        end
      rescue Exception => e
        NewRelic::Agent.notice_error(e)
      end
    end
  end

  def destroy
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
    page_hash      = {}
    scoper.each do |facebook_page|
      if page_hash[facebook_page.profile_id.to_s]
        page_hash[facebook_page.profile_id.to_s]["facebook_pages"] << facebook_page
      else
        page_hash[facebook_page.profile_id.to_s] = {
          "facebook_pages"  => [facebook_page],
        }
      end
    end
    page_hash
  end

  def scoper
    current_account.facebook_pages
  end

  def fb_client
    @fb_client     = Facebook::Oauth::FbClient.new(fb_call_back_url)
  end

  def load_item
    @item = current_account.facebook_pages.find(params[:id])
  end

  def fb_call_back_url(action="index") 
    url_for(:host => current_account.full_domain, :action => action)
  end

  def set_session_state
    session[:state] = Digest::MD5.hexdigest("#{Helpdesk::SECRET_3}#{Time.now.to_f}")
  end
  
  def social_revamp_enabled?
    redirect_to admin_social_facebook_streams_url if  current_account.features?(:social_revamp)
  end

end