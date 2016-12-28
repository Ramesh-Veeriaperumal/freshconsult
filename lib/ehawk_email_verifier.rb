require 'timeout'
class EhawkEmailVerifier
  include AccountConstants
  include Redis::OthersRedis
  include Redis::RedisKeys

  def scan args
    @args = args
    @api_key = EhawkConfig::API_KEY
    @api_response = {}
    if !@args["account_details"]["source_ip"].present? 
      @api_response["error_message"] = "Source IP is not been provided"
    elsif !@args["account_details"]["email"].present? 
      @api_response["error_message"] = "Email is not been provided"
    else
      @api_response = get_response
      check_status if @api_response["error_message"].empty?
    end
    return @api_response
  end

  def get_response 
    @parameters = construct_params
    begin
      Timeout.timeout(300) do 
        response = HTTParty.send('post', EhawkConfig::URL, :body => @parameters)
        @final_response = parse_response response.body
        email = @args["account_details"]["email"]
        Rails.logger.info "Response from Ehawk for email #{email} :#{response.body}"
      end
    rescue Timeout::Error => e
      Rails.logger.info  "Timeout Error in e-hawk api for parameters #{@parameters.inspect} : #{e.message} - #{e.backtrace}"
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
  end

  def construct_params
    http_body = {}

    http_body[:apikey] = @api_key
    http_body[:ip] = @args["account_details"]["source_ip"]
    http_body[:email] = @args["account_details"]["email"]
    http_body[:phone] = @args["account_details"]["phone"] if @args["account_details"]["phone"].present?
    http_body[:city] = @args["account_details"]["city"] if @args["account_details"]["city"].present?
    http_body[:country] = @args["account_details"]["country_code"] if @args["account_details"]["country_code"].present?
    http_body[:first_name] = @args["account_details"]["first_name"] if @args["account_details"]["first_name"].present?
    http_body[:last_name] = @args["account_details"]["last_name"] if @args["account_details"]["last_name"].present?
    http_body[:website] = @args["metrics"]["first_landing_url"] if @args["metrics"]["first_landing_url"].present?
    http_body[:referrer] = @args["metrics"]["first_referrer"] if @args["metrics"]["first_referrer"].present?
    http_body[:revert] = @args["account_details"]["revert"] if @args["account_details"]["revert"].present? # set value yes 
    http_body[:timeout] = "no"
    return http_body
  end
  
  def parse_response json_data
    parsed_data = JSON.parse(json_data)
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
    end
    return response
  end

  def check_activity_status
    activity_status = risk_status @api_response["activity_score"]
    @api_response["reason"] << @api_response["activity_details"] 
    if repeated_emails >= 5
      @api_response["status"] = 5 if (@api_response["status"] == 4 && activity_status == 4)
      activity_status += 1 if activity_status <= 3 
    end
    @api_response["status"] = [activity_status, @api_response["status"]].max
  end

  def check_community_status
    community_status = risk_status @api_response["community_score"]
    @api_response["reason"] << @api_response["community_details"]
    if @api_response["community_details"] =~ EHAWK_SPAM_COMMUNITY_REGEX 
      @api_response["status"] = 5 if (@api_response["status"] == 4 && community_status == 4)
      community_status += 1 if community_status <= 3 
    end 
    @api_response["status"] = [community_status, @api_response["status"]].max
  end

  def check_email_status
    email_status = risk_status @api_response["email_score"]
    @api_response["reason"] << @api_response["email_details"] 
    if @api_response["email_details"] =~ EHAWK_SPAM_EMAIL_REGEX
      @api_response["status"] = 5 if (@api_response["status"] == 4 && email_status == 4)
      email_status += 1  if email_status <= 3 
    end
    @api_response["status"] = [email_status, @api_response["status"]].max
  end

  def check_ip_status
    ip_status = risk_status @api_response["ip_score"]
    @api_response["reason"] << @api_response["ip_details"] 
    if @api_response["ip_details"] =~ EHAWK_IP_BLACKLISTED_REGEX 
      @api_response["status"] = 5 if (@api_response["status"] == 4 && ip_status == 4)
      ip_status += 1  if ip_status <= 4 
    end
    @api_response["status"] = [ip_status, @api_response["status"]].max
  end

  def spam_country_regex
      country_regex = get_others_redis_key(EHAWK_SPAM_COUNTRY_REGEX_KEY)
      regex = country_regex ? Regexp.compile(country_regex, true) : nil
  end

    def spam_geolocation_regex
      geolocation_regex = get_others_redis_key(EHAWK_SPAM_GEOLOCATION_REGEX_KEY)
      regex = geolocation_regex ? Regexp.compile(geolocation_regex, true) : EHAWK_SPAM_GEOLOCATION_REGEX
    end

    def check_geolocation_status
      location_regex = spam_country_regex
      if location_regex && ((@api_response["country"] =~ location_regex) || (@api_response["city"] =~ location_regex))
        geolocation_status = risk_status @api_response["total_score"]
        @api_response["reason"] << @api_response["geolocation_details"] + "," if @api_response["geolocation_details"].present?
        geolocation_status += 1 if ((@api_response["status"] == geolocation_status) || (@api_response["geolocation_details"] =~ spam_geolocation_regex)) && geolocation_status < 5
        @api_response["status"] = [geolocation_status, @api_response["status"]].max
      end
    end

  def risk_status score
    if score < -90
      status = 5
    elsif score < -60
      status = 4
    elsif score < -40
      status = 3
    elsif score < -20
      status = 2 
    elsif score < -2      
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
  
end
