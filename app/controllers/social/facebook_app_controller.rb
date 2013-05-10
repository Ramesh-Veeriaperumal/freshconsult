class Social::FacebookAppController < ApplicationController
	require 'koala'

  def fb_index
    @config = File.join(Rails.root, 'config', 'facebook.yml')
    @tokens = (YAML::load_file @config)[Rails.env]
    if params[:signed_request]
      signed_request = authenticator.parse_signed_request(params[:signed_request])
      page_id = signed_request["page"]["id"] if signed_request["page"]
      @portal_url = portal_for_page(page_id) if page_id
      if signed_request["oauth_token"] and !session[:facebook_login]
        redirect_to @portal_url + "/sso/facebook?facebook_tab=true"
      else
        redirect_to @portal_url + "/support/home?source=facebook"
      end
    end
  end

  def facebook_authentication
    session[:access_token] = authenticator.get_access_token(params[:code])
    redirect_to fb_index_social_fb_path
  end


  private

  def authenticator
    @authenticator ||= Koala::Facebook::OAuth.new(@tokens['app_id'], @tokens['secret_key'], "http://localhost:3000/social/facebook_app/facebook_authentication")
  end

  def access_token
    session[:access_token] || access_token_from_cookie
  end

  def access_token_from_cookie
    authenticator.get_user_info_from_cookies(request.cookies)['access_token']
  rescue => err
    warn err.message
  end

  def portal_for_page page_id
    fb_page = Social::FacebookPage.find_by_page_id(page_id)
    if fb_page
      portal = Portal.find_by_account_id_and_product_id(fb_page.account_id, fb_page.product_id) if fb_page.product_id
      portal_url = (portal) ? portal.portal_url : fb_page.account.full_domain
      "#{request.scheme}://#{portal_url}"
    end
  end

end