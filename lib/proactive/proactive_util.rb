module Proactive::ProactiveUtil
  include ::Proactive::Constants
  include Redis::RedisKeys
  include Redis::OthersRedis

  def make_http_call(route, request_method)
    hrp = HttpRequestProxy.new
    service_params = {
      domain: ProactiveServiceConfig['service_url'],
      rest_url: route,
      skip_blacklist_verification: true
    }
    if cname_params.present?
      cname_params[:user_id] = api_current_user.id
      service_params[:body] = cname_params.to_json
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

  def trigger_contact_import(args)
    Import::SimpleOutreachWorker.perform_async(args)
  end

  def make_rud_request(request_method, type, api_route)
    route = "#{api_route}/#{params[:id]}"
    service_response = make_http_call(route, request_method)
    if @item.present?
      render type.to_sym, status: service_response[:status]
    else
      head service_response[:status]
    end
  end

  def check_proactive_feature
    render_request_error(:require_feature, 403, feature: 'Proactive Support') unless current_account.proactive_outreach_enabled?
  end

  def generate_jwt_token
    jwt_payload = { account_id: current_account.id, sub: 'helpkit', domain: current_account.full_domain }
    @auth = "Token #{sign_payload(jwt_payload)}"
  end

  def outreach_import_limit
    custom_limit = get_others_redis_hash_value(CUSTOM_EMAIL_OUTREACH_LIMIT, Account.current.id)
    limit = if custom_limit
              custom_limit.to_i
            elsif current_account.subscription.trial?
              SIMPLE_OUTREACH_TRIAL_LIMIT
            else
              SIMPLE_OUTREACH_IMPORT_LIMIT
            end    
  end
end
