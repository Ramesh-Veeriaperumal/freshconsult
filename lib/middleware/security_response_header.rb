class Middleware::SecurityResponseHeader
  include Redis::RedisKeys
  include Redis::OthersRedis

  HTML_FORMATS = ['text/html', 'application/xml+html'].freeze
  FEEDBACK_WIDGET_PATHS = ['/widgets/feedback_widget', '/widgets/feedback_widget/new', '/widgets/feedback_widget/thanks'].freeze
  BYPASS_CHECK_SUBDOMAINS = %w(login signup).freeze
  LOGIN_PATH = 'login'.freeze
  SUPPORT_PATH = 'support'.freeze

  def initialize(app)
    @app = app
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
    FEEDBACK_WIDGET_PATHS.include?(@req_path) || @req_path.include?(SUPPORT_PATH)
  end

  def ignore_domain?
    sub_domain = @host.split('.')[0]
    BYPASS_CHECK_SUBDOMAINS.inject(false) { |should_skip, skip_domain| should_skip || sub_domain.include?(skip_domain) }
  end

  def add_security_headers(headers)
    begin
      headers['X-XSS-Protection'] = '1; mode=block'

      return headers unless html_response?(headers)
      return headers if ignore_domain?

      if @req_path.include? LOGIN_PATH
        headers['X-Frame-Options'] = 'DENY'
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
