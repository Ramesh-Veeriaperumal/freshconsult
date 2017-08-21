module Email::EmailService::IpPoolHelper
  require 'net/http/persistent'
  include Redis::RedisKeys
  include Redis::OthersRedis

  FD_EMAIL_SERVICE = (YAML::load_file(File.join(Rails.root, 'config', 'fd_email_service.yml')))[Rails.env]
  SENDER_CONFIG_URLPATH = FD_EMAIL_SERVICE["sender_config_urlpath"]
  
  class SenderConfigFetchError < StandardError
  end

  def sender_config_key(account_id, email_type)
    EMAIL_SENDER_CONFIG % {:account_id => account_id.to_s, :email_type => email_type}
  end

  def get_sender_config_from_redis(account_id,email_type)
    redis_value = get_others_redis_key(sender_config_key(account_id, email_type))
    unless redis_value.nil?
      config = {
        "categoryId" => redis_value.split(":").first,
        "ipPoolName" => redis_value.split(":").last
      }
      return config
    end
  end

  def get_sender_config_email_type(email_type)
    if email_type == "Reply" || email_type == "Forward" || email_type == "Notify Outbound Email"
      return email_type
    else
      return "Notification Email"
    end
  end
  #stores related account's email-sender config details in redis with 1 day validity
  def set_sender_config account_id, config, email_type
    category_id = config["categoryId"]
    ip_pool = config["ipPoolName"]
    set_others_redis_key(sender_config_key(account_id, email_type),
                         "#{category_id}:#{ip_pool}",
                         1.day.to_i) unless config.nil?
  end

  def get_sender_config(account_id, category_id, email_type)
    email_type = get_sender_config_email_type(email_type)
    if (Account.current.launched?(:sender_config_check_enabled))
      res = get_sender_config_from_redis account_id, email_type
      if res.nil?
        res = fetch_sender_config account_id, category_id, email_type
        set_sender_config(account_id, res, email_type) if (res.present? && res["canBeSaved"].present? && res["canBeSaved"] == "1")
      end
      return res
    end
  end

  def fetch_sender_config(account_id, category_id, email_type)
    Rails.logger.info "Fetching Sender Config for #{account_id}"
    begin
      con = Faraday.new(Email::EmailService::EmailDelivery::EMAIL_SERVICE_HOST) do |faraday|
              faraday.response :json, :content_type => /\bjson$/ 
              faraday.adapter  :net_http_persistent
            end
      response = con.post do |req|
        req.url "/" + SENDER_CONFIG_URLPATH
        req.headers['Content-Type'] = 'application/json'
        req.headers['Authorization'] = Email::EmailService::EmailDelivery::EMAIL_SERVICE_AUTHORISATION_KEY
        req.options.timeout = Email::EmailService::EmailDelivery::EMAIL_SERVICE_TIMEOUT
        req.body = prepare_request_param account_id, category_id, email_type
      end
      if response.status != 200
        Rails.logger.info "Failed to fetch Sender Config due to : #{response.body["Message"]}"
        raise SenderConfigFetchError, response.body["Message"]
      end
      return response.body["config"]
    rescue Exception => e
        Rails.logger.debug "Exception occured while getting sender config from \"Sender config Service\" : #{e} - #{e.message} - #{e.backtrace}"
        NewRelic::Agent.notice_error(e)
    end
  end

  def prepare_request_param(account_id, category_id, email_type)
    param = { "accountId" => account_id,
      "categoryId" => category_id,
      "emailType" => email_type
    }
    return param.to_json
  end

end