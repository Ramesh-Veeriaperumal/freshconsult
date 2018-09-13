class Admin::Social::FacebookPagesController < Admin::AdminController

  before_filter { access_denied unless current_account.basic_facebook_enabled? }
  
  before_filter :load_item, :only => [:destroy]

  def enable_pages
    pages = params[:enable][:pages]
    pages = pages.reject(&:blank?)
    errors = add_to_db pages
    flash[:error] = errors if errors.present?
    redirect_to admin_social_facebook_streams_url
  end

  def destroy
    redirect_to admin_social_facebook_streams_url unless @facebook_page
    
    remove_page_tab if @facebook_page.page_token_tab
    @facebook_page.destroy 
    flash[:notice] = t('facebook.deleted', :facebook_page => @facebook_page.page_name)
    redirect_to admin_social_facebook_streams_url
  end
  
  private
  
  def add_to_db fb_pages
    errors = ''
    
    fb_pages.each do |fb_page|
      fb_page = ActiveSupport::JSON.decode fb_page
      fb_page.symbolize_keys!
      page = scoper.find_by_page_id(fb_page[:page_id])
      unless page.blank?
        page_params = fb_page.except(:fetch_since, :message_since)
        page.update_attributes(page_params)
      else
        begin
          break unless current_account.add_new_facebook_page?
          page = scoper.new(fb_page)
          page.save 
        rescue Social::FacebookPage::AlreadyLinkedException => e
          Rails.logger.debug "Trying to add a page that is already present in another account, account: #{current_account.id}, fb_page: #{fb_page[:page_id]}"
          errors = I18n.t('facebook.page_already_subscribed')
        rescue Social::FacebookPage::NoResponseException => e
          Rails.logger.error "Something went wrong while making the facebook subscription call, account: #{current_account.id}, fb_page: #{fb_page[:page_id]}"
          errors = I18n.t('facebook.no_subscription_response')
        end
      end
    end

    errors
  end
  
  def load_item
    @facebook_page = scoper.find_by_id(params[:id])
  end
  
  def scoper
    current_account.facebook_pages
  end
  
  def remove_page_tab
    fb_page_tab = Facebook::PageTab::Configure.new(@facebook_page, "page_tab")
    fb_page_tab.execute("remove") if fb_page_tab.execute("get") 
  end
  
end
