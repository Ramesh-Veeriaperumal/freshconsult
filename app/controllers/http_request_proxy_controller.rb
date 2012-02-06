class HttpRequestProxyController < ApplicationController
  def fetch
    httpRequestProxy = HttpRequestProxy.new
    render httpRequestProxy.fetch(params, request);
  end
end
