module Facebook
  module Oauth
    class Validator

      def self.has_permissions? token
        fb_user = Koala::Facebook::API.new(token)
        permissions = fb_user.get_connections('me','permissions').first
        (Facebook::Oauth::Constants::PAGE_TAB_PERMISSION - permissions.keys).empty?
      end

      def self.read_facebook signed_request
        begin
          oauth = Koala::Facebook::OAuth.new(FacebookConfig::PAGE_TAB_APP_ID,FacebookConfig::PAGE_TAB_SECRET_KEY)
          facebook_data = oauth.parse_signed_request(signed_request)
          facebook_data["oauth_token"] = nil unless facebook_data["oauth_token"] and has_permissions?(facebook_data["oauth_token"])
          page = facebook_data["page"]["id"] if facebook_data["page"]
          {
            :page_id => facebook_data["page"]["id"],
            :oauth_token => facebook_data["oauth_token"]
          }
        rescue Exception => e
          return {}
        end
      end
    end
  end
end
