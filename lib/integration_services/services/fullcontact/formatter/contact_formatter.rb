module IntegrationServices::Services
  module Fullcontact::Formatter
    class ContactFormatter

      def initialize api_response
        @contact_response = api_response
        set_social_profiles
      end

      def social_profiles
        @social_profiles
      end

      def full_name
        return @contact_response.fetch("contactInfo", {}).fetch("fullName", nil) if likelihood > 0.85
        ""
      end

      def likelihood
        @contact_response["likelihood"] || 0
      end

      def avatar
        image_url = nil
        @contact_response["photos"].each do |prof|
          image_url = prof["url"] if ((["facebook","googleplus","gravatar","linkedin","twitter"].include?(prof["typeId"])) && (image_url.nil? || prof["isPrimary"]))
        end
        image_url
      end

      def location
        @contact_response.fetch("demographics", {}).fetch("locationDeduced", {}).fetch("deducedLocation", "") if location_likelihood > 0.85
      end

      def location_likelihood
        return @contact_response.fetch("demographics", {}).fetch("locationDeduced", {}).fetch("likelihood", 0)
      end

      def organization #primary org from fullcontact
        @contact_response["organizations"].each do |org|
          return org["name"] if org["isPrimary"]
        end 
        ""
      end

      def title #title from primary org from fullcontact
        @contact_response["organizations"].each do |org|
          return org["title"] if org["isPrimary"]
        end
        ""
      end

      def set_social_profiles
        @social_profiles = {}
        @contact_response["socialProfiles"].each do |profile|
          case profile["typeId"]
          when *["aolchat", "skype", "facebookchat"]
            @social_profiles[profile["typeId"]] = profile["username"]
          when "twitter"
            @social_profiles["twitter_id"]  = profile["username"]
            @social_profiles["twitter_url"] = profile["url"]
          else
            @social_profiles[profile["typeId"]] = profile["url"]
          end
        end
      end
    end
  end
end