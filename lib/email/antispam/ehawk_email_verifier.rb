require 'timeout'
module Email::Antispam
  class EhawkEmailVerifier

    class << self

    include AccountConstants
    include Redis::OthersRedis
    include Redis::RedisKeys
    include ParserUtil

    IP_DISTANCE_VELOCITY_LIMIT = 500

  	def scan args, account_id
      begin 
    	  @args = args
    	  @api_key = EhawkConfig::API_KEY
    	  @api_response = {}
    	  if !@args["account_details"]["source_ip"].present? 
    	  	@api_response["error_message"] = "Ehawk Source IP is not been provided"
    	  elsif !@args["account_details"]["email"].present? 
    	  	@api_response["error_message"] = "Ehawk Email is not been provided"
    	  else
    		  @api_response = get_response account_id
    		  check_status if @api_response["error_message"].empty?
    		end
      rescue => e
        Rails.logger.info "Error occured in Ehawk Email Verifier #{e.class} :: #{e.message} :: #{e.backtrace}"
      end
    	return @api_response
  	end

    private

  	def get_response account_id
  		@parameters = construct_params
      begin
        Timeout.timeout(60) do 
          response = HTTParty.send('post', EhawkConfig::URL, :body => @parameters)
          Rails.logger.info "Response from Ehawk for email #{@parameters[:email]}, account_id #{account_id} :#{response.body}"
          @final_response = parse_response response.body
        end
      rescue Timeout::Error => e
        Rails.logger.info  "Timeout Error in Ehawk api for parameters #{@parameters.inspect} : #{e.message} - #{e.backtrace}"
      end
  		return @final_response
  	end

    def check_status
      @api_response["status"] = 0   # no_risk = 0, some_risk = 1, medium_risk = 2, high_risk = 3, very_high = 4, spam = 5
      @api_response["reason"] = ""
    	check_activity_status
      check_community_status
      check_email_status
    	check_ip_status
      check_geolocation_status
      remove_trailing_comma
    end

  	def construct_params
      parsed_email = parse_email_with_domain(@args["account_details"]["email"])
  		http_body = {}

  		http_body[:apikey] = @api_key
      http_body[:ip] = @args["account_details"]["source_ip"]
      http_body[:email] = get_valid_email(@args["account_details"]["email"])
      http_body[:domain] = parsed_email[:domain]
      http_body[:phone] = @args["account_details"]["phone"] if @args["account_details"]["phone"].present?
      http_body[:city] = @args["account_details"]["city"] if @args["account_details"]["city"].present?
      http_body[:country] = @args["account_details"]["country_code"] if @args["account_details"]["country_code"].present?
      http_body[:first_name] = @args["account_details"]["first_name"] if @args["account_details"]["first_name"].present?
      http_body[:last_name] = @args["account_details"]["last_name"] if @args["account_details"]["last_name"].present?
      http_body[:website] = @args["account_details"]["first_landing_url"] if @args["account_details"]["first_landing_url"].present?
      http_body[:referrer] = @args["account_details"]["first_referrer"] if @args["account_details"]["first_referrer"].present?
      http_body[:revert] = @args["account_details"]["revert"] if @args["account_details"]["revert"].present? # set value yes while testing
      http_body[:timeout] = "no"
      return http_body
    end
    
    def parse_response json_data
    	parsed_data = JSON.parse(json_data)
      unless parsed_data["area"].nil?
        response = parse_new_format_response parsed_data
      else
        response = parse_old_format_response parsed_data
      end
      response 
    end
    
    def parse_old_format_response parsed_data
      response = {}
      response["error_status"] = parsed_data["status"]
      response["error_message"] = parsed_data["error_message"]
      response["risk_score"] = parsed_data["score"][1]
      response["risk_level"] = parsed_data["score"][2]
      if parsed_data["scores"].present?
      	response["ip_score"] = parsed_data["scores"]["ip"][1]
      	response["email_score"] = parsed_data["scores"]["email"][1]
      	response["geolocation_score"] = parsed_data["scores"]["geolocation"][1]
      	response["activity_score"] = parsed_data["scores"]["activity"][1] 
      	response["community_score"] = parsed_data["scores"]["community"][1]
      	response["fingerprint_score"] = parsed_data["scores"]["fingerprint"][1]
      end
      if parsed_data["details"].present?
  	    response["total_score"] = parsed_data["details"]["score_total"]
  	    response["device_fingerprint"] = parsed_data["details"]["fingerprint"]
  	    response["device_fingerprint_hits"] = parsed_data["details"]["fingerprint_hits"]
  	    response["city"] = parsed_data["details"]["ip"]["city"]
  	    response["country"] = parsed_data["details"]["ip"]["country"]
  	    response["timezone"] = parsed_data["details"]["ip"]["timezone"]
  	    response["ip_details"] = parsed_data["details"]["ip"]["score_details"].join(",") if parsed_data["details"]["ip"]["score_details"].present?
  	    response["email_details"] = parsed_data["details"]["email"]["score_details"].join(",") if parsed_data["details"]["email"].present?
  	    response["activity_details"] = parsed_data["details"]["activity"]["score_details"].join(",") if parsed_data["details"]["activity"].present?
  	    response["community_details"] = parsed_data["details"]["community"]["score_details"].join(",") if parsed_data["details"]["community"].present?
        response["geolocation_details"] = parsed_data["details"]["geo"]["score_details"].join(",") if parsed_data["details"]["geo"].present?
  	  end
  	  return response
    end

    def parse_new_format_response parsed_data
      response = {}
      response["error_status"] = parsed_data["status"]
      response["error_message"] = parsed_data["error_message"]
      if parsed_data["score"].present?
        response["risk_level"] = parsed_data["score"]["type"]
        response["total_score"] = parsed_data["score"]["total"]
      end
      if parsed_data["area"].present?
        response["ip_score"] = parsed_data["area"]["ip"]
        response["email_score"] = parsed_data["area"]["email"]
        response["geolocation_score"] = parsed_data["area"]["geolocation"]
        response["activity_score"] = parsed_data["area"]["activity"]
        response["community_score"] = parsed_data["area"]["community"]
        response["fingerprint_score"] = parsed_data["area"]["fingerprint"]
      end
      if parsed_data["fingerprint"].present?
        response["fingerprint_hits"] = parsed_data["fingerprint"]["hits"] 
        response["fingerprint"] = parsed_data["fingerprint"]["id"]
      end
      if parsed_data["ip_location"].present?
        response["city"] = parsed_data["ip_location"]["city"]
        response["country"] = parsed_data["ip_location"]["country"]
        response["timezone"] = parsed_data["ip_location"]["timezone"]
      end
      if parsed_data["risk_hits"].present?
        response["ip_details"] = parsed_data["risk_hits"]["ip"].join(",") if parsed_data["risk_hits"]["ip"].present?
        response["email_details"] = parsed_data["risk_hits"]["email"].join(",") if parsed_data["risk_hits"]["email"].present?
        response["activity_details"] = parsed_data["risk_hits"]["activity"].join(",") if parsed_data["risk_hits"]["activity"].present?
        response["community_details"] = parsed_data["risk_hits"]["community"].join(",") if parsed_data["risk_hits"]["community"].present?
        response["geolocation_details"] = parsed_data["risk_hits"]["geolocation"].join(",") if parsed_data["risk_hits"]["geolocation"].present?
      end
      return response
    end

    def check_activity_status
      activity_status = risk_status @api_response["activity_score"]
      @api_response["reason"] << " activity_details : #{@api_response["activity_details"]} ," if @api_response["activity_details"].present? 
      activity_status += 1 if ((@api_response["status"] == activity_status) || (repeated_emails >= 3)) && activity_status < 5  
      @api_response["status"] = [activity_status, @api_response["status"]].max
    end

    def check_community_status
      community_status = risk_status @api_response["community_score"]
      @api_response["reason"] << " community_details : #{@api_response["community_details"]} ," if @api_response["community_details"].present? 
      community_status += 1 if ((@api_response["status"] == community_status) || (@api_response["community_details"] =~ spam_community_regex)) && community_status < 5 
      @api_response["status"] = [community_status, @api_response["status"]].max
    end

    def check_email_status
    	email_status = risk_status @api_response["email_score"]
    	@api_response["reason"] << " email_details : #{@api_response["email_details"]} ," if @api_response["email_details"].present?
    	email_status += 1 if ((@api_response["status"] == email_status) || (@api_response["email_details"] =~ spam_email_regex)) && email_status < 5
    	@api_response["status"] = [email_status, @api_response["status"]].max
    end

    def check_ip_status
      ip_status = risk_status @api_response["ip_score"]
    	@api_response["reason"] << " ip_details : #{@api_response["ip_details"]} ," if @api_response["ip_details"].present?
    	ip_status += 1   if ((@api_response["status"] == ip_status) || (@api_response["ip_details"] =~ spam_ip_regex)) && ip_status < 5
    	@api_response["status"] = [ip_status, @api_response["status"]].max
    end

    def check_geolocation_status
      location_regex = spam_country_regex
      if location_regex && ((@api_response["country"] =~ location_regex) || (@api_response["city"] =~ location_regex))
        geolocation_status = risk_status @api_response["total_score"]
        @api_response["reason"] << " geolocation_details : #{@api_response["geolocation_details"]} ," if @api_response["geolocation_details"].present?
        geolocation_status += 1 if ((@api_response["status"] == geolocation_status) || high_ip_distance_velocity? || (@api_response["geolocation_details"] =~ spam_geolocation_regex)) && geolocation_status < 5
        @api_response["status"] = [geolocation_status, @api_response["status"]].max
      end
    end

    def risk_status score
    	if score <= -90
    		status = 5
    	elsif score <= -60
    		status = 4
    	elsif score <= -40
    		status = 3
    	elsif score <= -20
        status = 2 
      elsif score <= -1 			
    	  status = 1
    	else
    		status = 0
    	end
    	status
    end		
    
    def repeated_emails
      if (@api_response["activity_details"] =~ /^(\d+)(\+?) Repeat/i )
        repeats = $1.to_i
      else
      	repeats = 0
      end
    end

    def high_ip_distance_velocity?
      if (@api_response["geolocation_details"] =~ /^IP Distance Velocity (.+)/i )
        distance = $1.gsub("k","000")
        distance_velocity = get_others_redis_key(EHAWK_IP_DISTANCE_VELOCITY_LIMIT_KEY)
        distance_velocity_limit = distance_velocity ? distance_velocity.to_i : IP_DISTANCE_VELOCITY_LIMIT
        return true if distance.to_i > distance_velocity_limit
      end
      return false
    end

    def spam_community_regex
      community_regex = get_others_redis_key(EHAWK_SPAM_COMMUNITY_REGEX_KEY)
      regex = community_regex ? Regexp.compile(community_regex, true) : EHAWK_SPAM_COMMUNITY_REGEX
    end

    def spam_email_regex
      email_regex = get_others_redis_key(EHAWK_SPAM_EMAIL_REGEX_KEY)
      regex = email_regex ? Regexp.compile(email_regex, true) : EHAWK_SPAM_EMAIL_REGEX
    end

    def spam_ip_regex
      ip_blacklisted_regex = get_others_redis_key(EHAWK_IP_BLACKLISTED_REGEX_KEY)
      regex = ip_blacklisted_regex ? Regexp.compile(ip_blacklisted_regex, true) : EHAWK_IP_BLACKLISTED_REGEX
    end

    def spam_country_regex
      country_regex = get_others_redis_key(EHAWK_SPAM_COUNTRY_REGEX_KEY)
      regex = country_regex ? Regexp.compile(country_regex, true) : nil
    end

    def spam_geolocation_regex
      geolocation_regex = get_others_redis_key(EHAWK_SPAM_GEOLOCATION_REGEX_KEY)
      regex = geolocation_regex ? Regexp.compile(geolocation_regex, true) : EHAWK_SPAM_GEOLOCATION_REGEX
    end

    def remove_trailing_comma
      @api_response["reason"] = @api_response["reason"][0..(@api_response["reason"].size)-2]
    end

    def get_valid_email email
      while (email =~ /(.*)\+(.*)\@(.*)/)
        email = "#{$1}@#{$3}"
      end
      return email
    end
    end
  end
end