class Middleware::SecurityResponseHeader
  include Cache::LocalCache

  HTML_FORMATS = ['text/html', 'application/xml+html'].freeze
  FEEDBACK_WIDGET_PATHS = ['/widgets/feedback_widget', '/widgets/feedback_widget/new', '/widgets/feedback_widget/thanks'].freeze
  BYPASS_CHECK_SUBDOMAINS = %w(login signup).freeze
  LOGIN_PATH = 'login'.freeze
  SSO_PATHS = ['/login/sso', '/login/saml', '/login/sso_v2', '/logout'].freeze
  SUPPORT_PATH = 'support'.freeze
  SUPPORT_IMAGE_UPLOAD_PATHS = ['/tickets_uploaded_images','/tickets_uploaded_images/create_file','/forums_uploaded_images','/forums_uploaded_images/create_file'].freeze # Used in support portal
  SEC_MIDDLEWARE_IGNORED_DOMAINS_KEY = 'IGNORED_CLICKJACK_DOMAINS'.freeze

  def initialize(app)
    @app = app
    # force clear on startup. Rails.cache can be backed by a external cache
    clear_lcached(SEC_MIDDLEWARE_IGNORED_DOMAINS_KEY)
  end

  def call(env)
    @req_path = env['PATH_INFO']
    @host = env['HTTP_HOST']
    status, headers, response = @app.call(env)
    headers = add_security_headers(headers)
    [status, headers, response]
  end

  def html_response?(headers)
    HTML_FORMATS.inject(false) { |is_html, format| is_html || headers['Content-Type'].include?(format) } if headers['Content-Type']
  end

  def ignore_path?
    FEEDBACK_WIDGET_PATHS.include?(@req_path) || @req_path.include?(SUPPORT_PATH) || SSO_PATHS.include?(@req_path) || SUPPORT_IMAGE_UPLOAD_PATHS.include?(@req_path)
  end

  def login_path?
    @req_path.include?(LOGIN_PATH) && !SSO_PATHS.include?(@req_path)
  end

  def logged_in?
    User.current.present?
  end

  def ignore_subdomain?
    sub_domain = @host.split('.')[0]
    BYPASS_CHECK_SUBDOMAINS.inject(false) { |should_skip, skip_domain| should_skip || sub_domain.include?(skip_domain) }
  end

  def ignore_domain?
    domains = fetch_lcached_set(SEC_MIDDLEWARE_IGNORED_DOMAINS_KEY, 2.hours)
    domains.include?(@host)
  end

  def ignore_x_frame_options?(headers)
    !html_response?(headers) || ignore_subdomain? || ignore_domain?
  end

  def add_security_headers(headers)
    begin
      headers['X-XSS-Protection'] = '1; mode=block'

      return headers if ignore_x_frame_options?(headers)

      if login_path?
        headers['X-Frame-Options'] = logged_in? ? 'SAMEORIGIN' : 'DENY'
      else
        headers['X-Frame-Options'] = 'SAMEORIGIN' unless ignore_path?
      end
    rescue Exception => e
      Rails.logger.error("Failed during security header processing. Domain=#{@host} ReqPath=#{@req_path} \n#{e.message}\n#{e.backtrace.join("\n")}")
      NewRelic::Agent.notice_error(e)
    end
    headers
  end
end
