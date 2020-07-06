module Admin::ShiftHelper
  include Admin::ShiftConstants
  include OutOfOfficeConstants

  def shift_service_request
    proxy_response = perform_shift_request(params, cname_params)
    response_body = proxy_response[:body]
    if success? proxy_response[:code]
      if index_page?
        @items = response_body['data']
        response.api_meta = response_body['meta']
      else
        @item = response_body['data']
        response.api_meta = response_body['meta']
        response.status = proxy_response[:code]
      end
    elsif response_body['errors'].present?
      proxy_errors(response_body, proxy_response[:code])
    else
      proxy_errors(response_body, proxy_response[:code])
    end
  end

  def proxy_errors(error_body, status)
    if index_page?
      render json: @items = error_body
    else
      render json: @item = error_body
    end
    response.status = status
  end

  def perform_shift_request(params = nil, cname_params = nil, custom_request = false, custom_request_options = {})
    extnd_url = custom_request ? custom_request_options[:url] : extended_url(action, params['id'])
    url = base_url + extnd_url
    x_request_id = (custom_request ? custom_request_options[:request_id] : request.uuid) || UUIDTools::UUID.timestamp_create.hexdigest
    options = { headers: shift_headers(x_request_id) }
    options[:body] = cname_params.to_json if cname_params.present?
    options[:body] = custom_request_options[:body].to_json if custom_request_options[:body].present?
    if custom_request.blank?
      page_params = index_page? ? append_page_params(params) : nil
    end
    options[:query] = page_params if page_params.present?
    options[:timeout] = TIMEOUT
    execute_shift_request(url, options, custom_request, custom_request_options)
  end

  def execute_shift_request(url, options, custom_request = false, custom_request_options = {})
    options[:verify_blacklist] = true
    action_method = custom_request ? custom_request_options[:action_method] : action
    proxy_response = HTTParty::Request.new(ACTION_METHOD_TO_CLASS_MAPPING[action_method], url, options).perform
    { code: proxy_response.code, body: proxy_response.parsed_response }
  rescue StandardError => e
    NewRelic::Agent.notice_error(e, description: 'error while hitting shift service')
    { code: 500, body: { 'code' => 'Internal Server Error' } } # shift service down
  end

  def extended_url(action, shift_id)
    case action
    when :index, :create
      SHIFT_INDEX
    else
      format(SHIFT_SHOW, shift_id: shift_id)
    end
  end

  def append_page_params(params)
    query_params = {}
    PAGE_PARAMS.each do |param|
      query_params[param] = params[param.to_s] if params[param.to_s].present?
    end
    query_params
  end

  def success?(code)
    SUCCESS_CODES.include?(code)
  end

  def index_page?
    action == :index
  end

  def base_url
    ShiftConfig['shift_service_host']
  end

  def shift_headers(x_request_id)
    { 'Authorization' => "Bearer #{jwt_token}", 'Content-Type' => 'application/json',
      'X-Request-ID' =>  x_request_id }
  end

  def jwt_token
    JWT.encode payload, ShiftConfig['jwt_secret'], 'HS256', 'alg' => 'HS256', 'typ' => 'JWT'
  end

  def payload
    { account_id: current_account.id.to_s, product: PRODUCT, domain: current_account.full_domain,
      user_id: User.current.id.to_s, org_id: current_account.organisation.try(:organisation_id).try(&:to_s) || '' }
  end

  def current_account
    @current_account ||= Account.current
  end
end
