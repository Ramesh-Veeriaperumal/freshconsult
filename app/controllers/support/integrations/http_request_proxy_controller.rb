class Support::Integrations::HttpRequestProxyController < ApplicationController
  include Integrations::AppsUtil
  
  skip_before_filter :check_privilege
  before_filter { |c| c.check_customer_app_access c.params[:app_name] }
  before_filter :verify_domain

  DOMAIN_WHITELIST = "INTEGRATION_WHITELISTED_DOMAINS"

  def fetch
    httpRequestProxy = HttpRequestProxy.new
    http_resp = httpRequestProxy.fetch(params, request);
    response.headers.merge!(http_resp.delete('x-headers')) if http_resp['x-headers'].present?
    render http_resp
  end


  private
    def verify_domain
      begin
        parsed_url = URI.parse(params[:domain])
        parsed_url = URI.parse("#{request.protocol}#{params[:domain]}") if parsed_url.scheme.nil?
        whitelisted = value_in_set?(DOMAIN_WHITELIST, parsed_url.host)
        unless whitelisted
          main_domain_regex = /^(?:(?>[a-z0-9-]*\.)+?|)([a-z0-9-]+\.(?>[a-z]*(?>\.[a-z]{2})?))$/i
          main_domain = parsed_url.host.gsub(main_domain_regex, '\1')
          whitelisted = value_in_set?(DOMAIN_WHITELIST, main_domain)
        end

        unless whitelisted
          Rails.logger.error "582bd05be5202a24d353d56978d95a8e10f48d6bWHITELIST #{parsed_url.host} is not in the whitelist for account id: #{current_account.id}"
          render :status => 404
        end
      rescue Exception => e
        NewRelic::Agent.notice_error(e,{:custom_params => {:account_id => current_account.id, :url => params[:domain] }})
        render :status => 404
      end
    end
end