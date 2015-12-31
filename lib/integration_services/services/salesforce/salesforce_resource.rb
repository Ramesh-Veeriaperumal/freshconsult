module IntegrationServices::Services
  module Salesforce
    class SalesforceResource < IntegrationServices::GenericResource
      
      def faraday_builder(b)
       super
       b.headers["Authorization"] = "OAuth #{@service.configs["oauth_token"]}"
       b.use FaradayMiddleware::FollowRedirects, limit: 3
       b.use FaradayMiddleware::Oauth2Refresh, {:oauth2_access_token => get_access_token_object, :limit => 3 }
      end
     
     def get_access_token_object
       oauth_options = Integrations::OAUTH_OPTIONS_HASH["salesforce"]
       oauth_configs = Integrations::OAUTH_CONFIG_HASH["salesforce"]
       oauth_options = oauth_options.symbolize_keys
       client = OAuth2::Client.new oauth_configs["consumer_token"], oauth_configs["consumer_secret"], oauth_options
       token_hash = { :access_token => @service.configs["oauth_token"], :refresh_token => @service.configs["refresh_token"], 
          :client_options => oauth_options, :header_format => {}}
       access_token = OAuth2::AccessToken.from_hash(client, token_hash)
     end

     def format_fields_block
      fields_block = lambda do |fields_hash|
        fields_hash = fields_hash["fields"]
        field_labels = Hash.new
        fields_hash.each do |field|
         field_label = CGI.escapeHTML(RailsFullSanitizer.sanitize(field["label"]))
         field_labels[field["name"]] = field_label if field_label.present?
        end
        field_labels.merge!("Address"=>"Address")
      end
     end

      def format_selected_fields fields,address_fields
        fields_array = fields.split(",")
        fields_array.push("Id")
        if fields_array.include?("Address")
          fields_array.map! { |x| x == "Address" ? address_fields : x }
          fields_array.flatten!
        end
        fields_array.uniq!
        fields_array.join(",")
      end

      def process_response(response, *success_codes, &block)
        if success_codes.include?(response.status)
          if response.env[:new_token]
            @service.update_configs([{:key => 'oauth_token', :value => response.env[:new_token]}])
            http_reset
          end 
          yield parse(response.body)
        elsif response.status.between?(400, 499)
          error = parse(response.body)
          raise RemoteError, "Error message: #{error.first['message']}", response.status.to_s
        else
          raise RemoteError, "Unhandled error: STATUS=#{response.status} BODY=#{response.body}"
        end
      end

      def escape_reserved_chars element
        element.gsub(/['\\]/){|match| "\\#{match}"}
      end

      def salesforce_rest_url
        "#{@service.instance_url}/services/data/v35.0"
      end

      def salesforce_old_rest_url
        "#{@service.instance_url}/services/data/v20.0"
      end
    end
  end
end