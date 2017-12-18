
module Social::SmartFilter
  include Social::Util
 
  def is_english?(text)
    language, time_taken = Helpdesk::DetectUserLanguage.language_detect(text)
    if language.nil?
      Rails.logger.info "Error detecting the language of the tweet #{text}"
    end
    language == 'en'
  end

  def smart_filter_initialize(data)
    begin
      Retry.retry_this(:max_tries => SmartFilterConfig::MAX_TRIES, :base_sleep_seconds => SmartFilterConfig::RETRY_BASE_SLEEP_SEC, :rescue => RestClient::Exception) do
        response = RestClient.put(SmartFilterConfig::API_ENDPOINT + SmartFilterConfig::INIT_URL, data, {"Content-Type"=>"application/json", "Authorization"=>SmartFilterConfig::AUTH_KEY}) 
        Rails.logger.info  "Response from Smart filter ML layer for init: Account_ID: #{Account.current.id} Params: #{data} Response code: #{response.code}"
        response.code
      end
    rescue RestClient::Exception => e
      Rails.logger.info "Error initializing smart filter Account_ID: #{Account.current.id} Params: #{data} Exception: #{e.message}, #{e.backtrace}"
      e.http_code
    rescue Exception => e
      Rails.logger.info "Error initializing smart filter. Account_ID: #{Account.current.id} Params: #{data} Exception: #{e.message}, #{e.backtrace}"
      e
    end
  end

  def smart_filter_query(data)
    begin
      response = RestClient.post(SmartFilterConfig::API_ENDPOINT + SmartFilterConfig::QUERY_URL, data, {"Content-Type"=>"application/json", "Authorization"=>SmartFilterConfig::AUTH_KEY}) 
      Rails.logger.info "Response from Smart filter ML layer for query: Account_ID: #{Account.current.id} Params: #{data} Response code: #{response.code} Response body: #{response.body}" 
      notify_social_dev("Smart filter query returned error code", {:msg => "Account_ID: #{Account.current.id} Params: #{data} Response code: #{response.code} Response body: #{response.body}"}) unless response.code == 200
      JSON.parse(response.body)["Prediction"]
    rescue Exception => e
      Rails.logger.info "Error querying smart filter. Account_ID: #{Account.current.id} Params: #{data} Exception: #{e.message}, #{e.backtrace}"
      notify_social_dev("Error querying smart filter", {:msg => "Account_ID: #{Account.current.id} Params: #{data} Exception: #{e.message}, #{e.backtrace}"})
      0
    end 
  end

  def smart_filter_feedback(data)
    begin
      Retry.retry_this(:max_tries => SmartFilterConfig::MAX_TRIES, :base_sleep_seconds => SmartFilterConfig::RETRY_BASE_SLEEP_SEC, :rescue => RestClient::Exception) do
        response = RestClient.put(SmartFilterConfig::API_ENDPOINT + SmartFilterConfig::FEEDBACK_URL, data, {"Content-Type"=>"application/json", "Authorization"=>SmartFilterConfig::AUTH_KEY}) 
        Rails.logger.info "Response from Smart filter ML layer for feedback: Account_ID: #{Account.current.id} Params: #{data} Response code: #{response.code}"
        response.code
      end
    rescue RestClient::Exception => e
      Rails.logger.info "Error sending feedback to smart filter Account_ID: #{Account.current.id} Params: #{data} Exception: #{e.message}, #{e.backtrace}"
      e.http_code
    rescue Exception => e
      Rails.logger.info "Error sending feedback to smart filter. Account_ID: #{Account.current.id} Params: #{data} Exception: #{e.message}, #{e.backtrace}"
      e
    end
  end
end