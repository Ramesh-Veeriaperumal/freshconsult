module Authlogic
  module Session
    module Cookies

      def ssl?
        ENV['HTTPS'] == 'on' || ENV['HTTP_X_FORWARDED_PROTO'] == 'https'
      end

      def save_cookie
        controller.cookies[cookie_key] = {
          :value => "#{record.persistence_token}::#{record.send(record.class.primary_key)}",
          :expires => remember_me_until,
          :domain => controller.cookie_domain,
          :httponly => true,
          :secure => ssl?
        }
      end

    end
  end
end
