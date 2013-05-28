class Social::FacebookAppController < ApplicationController
	require 'koala'

  def fb_index
    @config = File.join(Rails.root, 'config', 'facebook.yml')
    @tokens = (YAML::load_file @config)[Rails.env]
    if params[:signed_request]
      signed_request = authenticator.parse_signed_request(params[:signed_request])
      page_id = signed_request["page"]["id"] if signed_request["page"]
      portal_url = portal_for_page(page_id) if page_id
      if signed_request["oauth_token"]
        redirect_to "#{portal_url}/facebook/sso/facebook"
      else
        redirect_to "#{portal_url}/facebook/support/home"
      end
    end
  end


  private

  def authenticator
    @authenticator ||= Koala::Facebook::OAuth.new(@tokens['app_id'], @tokens['secret_key'])
  end

  def portal_for_page page_id
    fb_page = Social::FacebookPage.find_by_page_id(page_id)
    if fb_page
      portal = Portal.find_by_account_id_and_product_id(fb_page.account_id, 
                                  fb_page.product_id) if fb_page.product_id
      portal_url = (portal) ? portal.portal_url : fb_page.account.full_domain
      "#{request.scheme}://#{portal_url}"
    end
  end

end