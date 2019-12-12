module Admin::ShiftHelper
  include Admin::ShiftConstants

  def perform_shift_request(params = nil, cname_params = nil)
    url = base_url + extended_url(action, params['id'])
    options = { headers: headers }
    options[:body] = cname_params.to_json if cname_params.present?
    page_params = index_page? ? append_page_params(params) : nil
    options[:query] = page_params if page_params.present?
    options[:timeout] = TIMEOUT
    execute_shift_request(url, options)
  end

  def execute_shift_request(url, options)
    proxy_response = HTTParty::Request.new(ACTION_METHOD_TO_CLASS_MAPPING[action], url, options).perform
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

  def check_shift_params
    params[cname].permit(*REQUEST_PERMITTED_PARAMS)
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
