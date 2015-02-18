class Support::FacebookTabsController < SupportController

  skip_before_filter :portal_context, :page_message, :ensure_proper_protocol
  skip_filter :select_shard
  skip_before_filter :determine_pod
  skip_before_filter :verify_authenticity_token, :check_account_state
  skip_before_filter :unset_current_account, :set_current_account, :redirect_to_mobile_url
  skip_before_filter :set_time_zone, :check_day_pass_usage, :set_locale
  around_filter :select_facebook_shard, :if => [:process_signed_request, :map_facebook_page]

  def redirect
    portal_url = portal_for_page if @page_info && facebook_page_tab?
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
      @page_info = Facebook::Oauth::Validator.read_facebook(params[:signed_request]) if params[:signed_request]
    end

    def map_facebook_page
      facebook_page_mapping = Social::FacebookPageMapping.find(@page_info[:page_id])
      @account_id = facebook_page_mapping.account_id if facebook_page_mapping
    end

    def portal_for_page
      fb_page = Social::FacebookPage.find_by_page_id_and_account_id(@page_info[:page_id], @account_id)
      if fb_page
        portal_url = fb_page.account.full_domain
        "#{request.scheme}://#{portal_url}"
      end
    end

    def facebook_page_tab?
      Account.find(@account_id).features?(:facebook_page_tab)
    end
end