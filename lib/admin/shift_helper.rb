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
      index_page? ? @items = [] : proxy_errors(response_body, proxy_response[:code])
    end
  end

  def proxy_errors(error_body, status)
    render json: @item = error_body
    response.status = status
  end

  def perform_shift_request(params = nil, cname_params = nil, model_query_params = false)
    extnd_url = model_query_params ? (OUT_OF_OFFICE_INDEX + format(QUERY_PARAM, state_value: model_query_params)) : extended_url(action, params['id'])
    url = base_url + extnd_url
    options = { headers: headers }
    options[:body] = cname_params.to_json if cname_params.present?
    if model_query_params.blank?
      page_params = index_page? ? append_page_params(params) : nil
    end
    options[:query] = page_params if page_params.present?
    options[:timeout] = TIMEOUT
    execute_shift_request(url, options, model_query_params)
  end

  def execute_shift_request(url, options, model_query_params = false)
    options[:verify_blacklist] = true
    action_method = model_query_params ? :index : action
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

  def headers
    { 'Authorization' => "Bearer #{jwt_token}", 'Content-Type' => 'application/json' }
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
