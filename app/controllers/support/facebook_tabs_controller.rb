class Support::FacebookTabsController < SupportController

  skip_before_filter :portal_context, :page_message
  skip_filter :select_shard
  skip_before_filter :verify_authenticity_token, :check_account_state
  skip_before_filter :unset_current_account, :set_current_account, :redirect_to_mobile_url
  skip_before_filter :set_time_zone, :check_day_pass_usage, :set_locale
  around_filter :select_facebook_shard, :if => [:process_signed_request, :map_facebook_page]

  def redirect
    portal_url = portal_for_page if @page_info
    unless portal_url
      render :file => "#{Rails.root}/public/facebook-404.html"
    else
      if @page_info[:oauth_token]
        redirect_to "#{portal_url}/facebook/sso/facebook"
      else
        redirect_to "#{portal_url}/facebook/support/home"
      end
    end
  end

  def select_facebook_shard(&block)
    Sharding.select_shard_of(@account_id) do 
      yield 
    end
  end

  private

    def process_signed_request
      @page_info = fb_page_tab.read_facebook(params[:signed_request]) if params[:signed_request]
    end

    def map_facebook_page
      facebook_page_mapping = FacebookPageMapping.find(@page_info[:page_id])
      @account_id = facebook_page_mapping.account_id if facebook_page_mapping
    end

    def fb_page_tab
      @fb_page_tab ||= FBPageTab.new
    end

  	def portal_for_page
      fb_page = Social::FacebookPage.find_by_page_id_and_account_id(@page_info[:page_id], @account_id)
      if fb_page
        portal = Portal.find_by_account_id_and_product_id(fb_page.account_id, 
                                      fb_page.product_id) if fb_page.product_id
        portal_url = (portal) ? portal.portal_url : fb_page.account.full_domain
        "#{request.scheme}://#{portal_url}"
      end
    end
end