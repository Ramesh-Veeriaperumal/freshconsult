module Proactive::ProactiveUtil
  include ::Proactive::Constants

  def make_http_call(route, request_method)
    hrp = HttpRequestProxy.new
    service_params = if cname_params.present?
                       cname_params[:user_id] = api_current_user.id
                       { domain: ProactiveServiceConfig['service_url'], rest_url: route,
                         body: cname_params.to_json }
                     else
                       { domain: ProactiveServiceConfig['service_url'], rest_url: route }
                     end
    request_params = { method: request_method, auth_header: @auth }
    service_response = hrp.fetch_using_req_params(service_params, request_params)
    service_response[:headers] = hrp.all_headers
    if service_response[:text] != 'null'
      json_parsed = JSON(service_response[:text])
      @item = json_parsed
      @item = @item[@item.keys[0]] if SUCCESS_CODES.include?(service_response[:status])
    end
    service_response
  end
end
