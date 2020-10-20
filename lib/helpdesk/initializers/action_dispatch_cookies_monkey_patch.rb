# frozen_string_literal: true

ActionDispatch::Cookies.class_eval do
  SAME_SITE_NONE = 'SAME_SITE_NONE'.freeze
  HTTP_HEADER = 'Set-Cookie'.freeze

  def call(env)
    cookie_jar = nil
    status, headers, body = @app.call(env)
    merge_same_site = env[SAME_SITE_NONE] == true
    env[SAME_SITE_NONE] = nil

    if cookie_jar = env['action_dispatch.cookies']
      cookie_jar.write(headers, merge_same_site)
      headers[HTTP_HEADER] = headers[HTTP_HEADER].join("\n") if headers[HTTP_HEADER].respond_to?(:join)
    end

    [status, headers, body]
  end
end

ActionDispatch::Cookies::CookieJar.class_eval do
  def write(headers, merge_same_site = false)
    @set_cookies.each { |k, v| ::Rack::Utils.set_cookie_header!(headers, k, merge_same_site ? v.merge(same_site: :none, secure: true) : v) if write_cookie?(v) }
    @delete_cookies.each { |k, v| ::Rack::Utils.delete_cookie_header!(headers, k, v) }
  end
end
