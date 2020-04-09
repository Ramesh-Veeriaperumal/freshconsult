class HttpRequestWorker < BaseWorker
  sidekiq_options queue: :http_request, retry: 1, :failures => :exhausted

  def perform(args)
    args.symbolize_keys!
    if invalid_args?(args)
      Rails.logger.info "Invalid args in http request worker : #{args.inspect}"
    else
      make_http_call(args)
    end
  rescue Exception => e
    send_newrelic_exception(Account.current.id, args[:route], e)
    raise e
  end

  def invalid_args?(args)
    (args[:domain].nil? || args[:route].nil? || args[:request_method].nil?)
  end

  def make_http_call(args)
    domain = args[:domain]
    route = args[:route]
    data = args[:data]
    hrp = HttpRequestProxy.new
    service_params = {
      domain: domain,
      rest_url: route
    }
    service_params[:body] = data.to_json if data.present?
    service_params[:skip_blacklist_verification] = true if args[:skip_blacklist_verification]
    request_params = { method: args[:request_method], auth_header: args[:auth_header] }
    hrp.fetch_using_req_params(service_params, request_params)
  end

  def send_newrelic_exception(account_id, route, exception)
    NewRelic::Agent.notice_error(exception,
                                 args: "#{account_id}:#{route}:httprequestworker")
  end
end
