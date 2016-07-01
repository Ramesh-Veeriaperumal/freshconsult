module IntegrationServices::Services
  module Fullcontact::Formatter
    class CompanyFormatter
  
      def initialize(api_response)
        @company_response = api_response
      end

      def organization_name
        @company_response.fetch("organization", {}).fetch("name", "")
      end
      
      def language_locale
        @company_response.fetch("languageLocale", "")
      end

      def approx_employees
        @company_response.fetch("organization", {}).fetch("approxEmployees", nil)
      end

      def founded
        @company_response.fetch("organization", {}).fetch("founded", nil)
      end

      def overview
        @company_response.fetch("organization", {}).fetch("overview", nil)
      end

      def address
        #work || other
        full_address = ""
        @company_response.fetch("organization", {}).fetch("contactInfo", {}).fetch("addresses",{}).each do |addr|
          region_name = addr.fetch("region", {}).fetch("name", nil)
          country_name = addr.fetch("country", {}).fetch("name", nil)
          full_address = [addr["addressLine1"], addr["addressLine2"], addr["locality"], region_name, country_name, addr["postalCode"]].reject(&:blank?).map(&:to_s).join(', ') if (addr["label"] == "work" or full_address.blank?)
        end
        full_address
      end

    end
  end
end
