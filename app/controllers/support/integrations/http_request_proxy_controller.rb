class Support::Integrations::HttpRequestProxyController < ApplicationController
  include Integrations::AppsUtil
  
  skip_before_filter :check_privilege
  before_filter { |c| c.check_customer_app_access c.params[:app_name] }

  def fetch
    httpRequestProxy = HttpRequestProxy.new
    http_resp = httpRequestProxy.fetch(params, request);
    response.headers.merge!(http_resp.delete('x-headers')) if http_resp['x-headers'].present?
    render http_resp
  end
end