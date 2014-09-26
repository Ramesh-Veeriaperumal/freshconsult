Authlogic::Session::Base.class_eval do
  def sign_cookie
    return @sign_cookie if defined?(@sign_cookie)
    @sign_cookie = self.class.sign_cookie
  end

  # Accepts a boolean as to whether the cookie should be signed.  If true the cookie will be saved and verified using a signature.
  def sign_cookie=(value)
    @sign_cookie = value
  end

  # See sign_cookie
  def sign_cookie?
    sign_cookie == true || sign_cookie == "true" || sign_cookie == "1"
  end

  private

  def cookie_credentials
    if self.class.sign_cookie
      controller.cookies.signed[cookie_key] && controller.cookies.signed[cookie_key].split("::")
    else
      controller.cookies[cookie_key] && controller.cookies[cookie_key].split("::")
    end
  end

  def secure
    return controller.request.protocol == "https://"
  end

  # Accepts a boolean as to whether the cookie should be marked as secure.  If true the cookie will only ever be sent over an SSL connection.
  def secure=(value)
    @secure = value
  end

  def save_cookie
    remember_me_until_value = "::#{remember_me_until}" if remember_me?
    cookie = {
      :value => "#{record.persistence_token}::#{record.send(record.class.primary_key)}#{remember_me_until_value}",
      :expires => remember_me_until,
      :domain => controller.cookie_domain,
      :secure => secure,
      :httponly => httponly,
    }
    if sign_cookie?
      controller.cookies.signed[cookie_key] = cookie
    else
      controller.cookies[cookie_key] = cookie
    end
  end

  def httponly
    true
  end

  # Accepts a boolean as to whether the cookie should be marked as httponly.  If true, the cookie will not be accessable from javascript
  def httponly=(value)
    @httponly = value
  end

  # See httponly
  def httponly?
    httponly == true || httponly == "true" || httponly == "1"
  end
end

Authlogic::Session::Base.instance_eval do
  def secure(value = nil)
    rw_config(:secure, value, false)
  end
  alias_method :secure=, :secure

  # Should the cookie be signed? If the controller adapter supports it, this is a measure against cookie tampering.
  def sign_cookie(value = nil)
    if value && !controller.cookies.respond_to?(:signed)
      raise "Signed cookies not supported with #{controller.class}!"
    end
    rw_config(:sign_cookie, value, false)
  end
  alias_method :sign_cookie=, :sign_cookie

  def httponly(value = nil)
    rw_config(:httponly, value, false)
  end
  alias_method :httponly=, :httponly
end

Authlogic::TestCase.module_eval do
  class Authlogic::TestCase::MockSignedCookieJar < Authlogic::TestCase::MockCookieJar
    attr_reader :parent_jar # helper for testing

    def initialize(parent_jar)
      @parent_jar = parent_jar
    end

    def [](val)
      if signed_message = @parent_jar[val]
        payload, signature = signed_message.split('--')
        raise "Invalid signature" unless Digest::SHA1.hexdigest(payload) == signature
        payload
      end
    end

    def []=(key, options)
      options[:value] = "#{options[:value]}--#{Digest::SHA1.hexdigest options[:value]}"
      @parent_jar[key] = options
    end
  end
end

Authlogic::TestCase::MockCookieJar.class_eval do
  def signed
    @signed ||= Authlogic::TestCase::MockSignedCookieJar.new(self)
  end
end
