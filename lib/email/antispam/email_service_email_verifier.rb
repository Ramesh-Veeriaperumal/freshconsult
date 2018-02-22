require 'timeout'
module Email::Antispam
  class EmailServiceEmailVerifier
    class << self
    include Redis::OthersRedis
    include Redis::RedisKeys
    include ParserUtil

      def scan args, account_id, account_name, account_domain
        begin 
          @args = args
          api_response = {}
          if !@args["account_details"]["source_ip"].present? 
            api_response["error_message"] = "EmailServ - Source IP is not been provided"
          elsif !@args["account_details"]["email"].present? 
            api_response["error_message"] = "EmailServ - Email is not been provided"
          else
            api_response = validate_request(account_id, account_name, account_domain)
          end
        rescue => e
          Rails.logger.info "Error occured in EmailServ Account Validator #{e.class} :: #{e.message} :: #{e.backtrace}"
        end
        return api_response
      end

      private

      def validate_request(account_id, account_name, account_domain)
        @parameters = construct_params(account_name, account_domain)
        headers = { "Authorization"  => Email::EmailService::EmailDelivery::EMAIL_SERVICE_AUTHORISATION_KEY, "Content-Type" => "application/json" }
        parsed_response = {}
        begin
          Timeout.timeout(Email::EmailService::EmailDelivery::EMAIL_SERVICE_TIMEOUT) do 
            response = HTTParty.safe_send('post', "#{Email::EmailService::EmailDelivery::EMAIL_SERVICE_HOST}/#{Email::EmailService::EmailDelivery::ACCOUNT_VALIDATE_URLPATH}", :body => @parameters,:headers => headers)
            Rails.logger.info "Response from EmailServ for parameters :#{@parameters.inspect}  ---  #{response.body}"
            parsed_response = parse_response(response.body)
          end
        rescue Timeout::Error => e
          Rails.logger.info  "Timeout Error in EmailServ api for parameters #{@parameters.inspect} : #{e.message} - #{e.backtrace}"
        end
        return parsed_response
      end

      def construct_params(account_name, account_domain)
        parsed_email = parse_email_with_domain(@args["account_details"]["email"])
        http_body = {}
        http_body[:ipAddress] = @args["account_details"]["source_ip"]
        http_body[:emailAddress] = get_valid_email(@args["account_details"]["email"])
        http_body[:accountDomain] = account_domain
        http_body[:accountName] = account_name
        http_body[:phone] = @args["account_details"]["phone"] if @args["account_details"]["phone"].present?
        http_body[:city] = @args["account_details"]["city"] if @args["account_details"]["city"].present?
        http_body[:country] = @args["account_details"]["country_code"] if @args["account_details"]["country_code"].present?
        http_body[:firstName] = @args["account_details"]["first_name"] if @args["account_details"]["first_name"].present?
        http_body[:lastName] = @args["account_details"]["last_name"] if @args["account_details"]["last_name"].present?
        http_body[:website] = @args["account_details"]["first_landing_url"] if @args["account_details"]["first_landing_url"].present?
        http_body[:referrer] = @args["account_details"]["first_referrer"] if @args["account_details"]["first_referrer"].present?
        http_body[:cache_id] = @args["account_details"]["fd_cid"] if @args["account_details"]["fd_cid"].present?
        return http_body.to_json
      end

      def get_valid_email email
        while (email =~ /(.*)\+(.*)\@(.*)/)
          email = "#{$1}@#{$3}"
        end
        return email
      end

      def parse_response json_data
        parsed_data = JSON.parse(json_data)
        parsed_data["Results"] || {}
      end


    end
  end
end
