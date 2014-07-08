# Rack and ApplicationController Secure Cookie Setting.
module Rack
  module Utils

    def set_cookie_header_without_security!(header, key, value)
      case value
        when Hash
          domain  = "; domain="  + value[:domain] if value[:domain]
          path    = "; path="    + value[:path]   if value[:path]
          # According to RFC 2109, we need dashes here.
          # N.B.: cgi.rb uses spaces...
          expires = "; expires=" +
              rfc2822(value[:expires].clone.gmtime) if value[:expires]
          secure = "; secure"  if value[:secure]
          httponly = "; HttpOnly" if value[:httponly]
          value = value[:value]
      end
      value = [value] unless Array === value
      cookie = escape(key) + "=" +
          value.map { |v| escape v }.join("&") +
          "#{domain}#{path}#{expires}#{secure}#{httponly}"

      case header["Set-Cookie"]
        when nil, ''
          header["Set-Cookie"] = cookie
        when String
          header["Set-Cookie"] = [header["Set-Cookie"], cookie].join("\n")
        when Array
          header["Set-Cookie"] = (header["Set-Cookie"] + [cookie]).join("\n")
      end

      nil
    end
    module_function :set_cookie_header_without_security!

    def ssl?
      ENV['HTTPS'] == 'on' || ENV['HTTP_X_FORWARDED_PROTO'] == 'https'
    end
    module_function :ssl?

    def set_cookie_header!(header, key, value)
      value = { :value => value } if Hash != value.class
      value[:secure] = true if ssl?
      set_cookie_header_without_security!(header, key, value)
    end
    module_function :set_cookie_header!

  end
end

class ActionController::Response

  def ssl?
    is_ssl = false
    begin
      is_ssl = true if request && request.ssl?
    rescue
      #Empty.
    end
    if ENV['HTTPS'] == 'on' || ENV['HTTP_X_FORWARDED_PROTO'] == 'https'
      is_ssl = true
    end
    is_ssl
  end

  def set_cookie_with_security(key, value)
    value = { :value => value } if Hash != value.class
    if ssl?
      value[:secure] = true unless value.has_key?(:secure)
    end
    set_cookie_without_security(key, value)
  end

  alias_method_chain :set_cookie, :security

end
