
module Social::SmartFilter
  
  include Social::Util
  
  def smart_filter_accountID(type, account_id, unique_id)
    "#{account_id}_#{SMART_FILTER_CONTENT_TYPE[type]}_#{unique_id}"
  end

  def smart_filter_enitytID(type, account_id, entity_id)
    "#{account_id}_#{SMART_FILTER_CONTENT_TYPE[type]}_#{entity_id}"
  end
  
  def is_english?(text)
    language, time_taken = Helpdesk::DetectUserLanguage.language_detect(text)
    if language.nil?
      Rails.logger.info "social::twitter::socialsignal error in detecting the language of the tweet #{text}"
    end
    language == 'en'
  end

  def smart_filter_initialize(data)
    begin
      response = RestClient.put(SmartFilterConfig::API_ENDPOINT + SmartFilterConfig::INIT_URL, data, {"Content-Type"=>"application/json", "Authorization"=>SmartFilterConfig::AUTH_KEY}) 
      Rails.logger.info  "social::twitter::socialsignal response from Smart filter ML layer for init: Account_ID: #{Account.current.id} Params: #{data} Response code: #{response.code}"
      response.code
    rescue Exception => e
      error_message = "social::twitter::socialsignal error in initializing smart filter Account_ID: #{Account.current.id} Params: #{data} Exception: #{e.message}"
      log_errors(error_message, e)
      raise e
    end
  end

  def smart_filter_query(data, convert_all_relevant_tweets)
    begin
      Retry.retry_this(:max_tries => SmartFilterConfig::MAX_TRIES, :rescue => RestClient::Exception) do
        response = RestClient.post(SmartFilterConfig::API_ENDPOINT + SmartFilterConfig::QUERY_URL, data, {"Content-Type"=>"application/json", "Authorization"=>SmartFilterConfig::AUTH_KEY}) 
        Rails.logger.info "social::twitter::socialsignal response from Smart filter ML layer for query: Account_ID: #{Account.current.id} Params: #{data} Response code: #{response.code} Response body: #{response.body}" 
        JSON.parse(response.body)["Prediction"]
      end
    rescue Exception => e
      error_message = "social::twitter::socialsignal error in querying smart filter. Account_ID: #{Account.current.id} Params: #{data} Exception: #{e.message}"
      log_errors(error_message, e)
      notify_social_dev("social::twitter::socialsignal error in querying smart filter", {:msg => "Account_ID: #{Account.current.id} Params: #{data} Exception: #{e.message}, #{e.backtrace}"})
      convert_all_relevant_tweets ?  1 : 0;
    end 
  end

  def smart_filter_feedback(data)
    begin
      response = RestClient.put(SmartFilterConfig::API_ENDPOINT + SmartFilterConfig::FEEDBACK_URL, data, {"Content-Type"=>"application/json", "Authorization"=>SmartFilterConfig::AUTH_KEY}) 
      Rails.logger.info "social::twitter::socialsignal response from Smart filter ML layer for feedback: Account_ID: #{Account.current.id} Params: #{data} Response code: #{response.code}"
      response.code
    rescue Exception => e
      error_message = "social::twitter::socialsignal error in sending feedback to smart filter Account_ID: #{Account.current.id} Params: #{data} Exception: #{e.message}"
      log_errors(error_message, e)
      raise e
    end
  end

  def log_errors(message, error)
    Rails.logger.info message
    NewRelic::Agent.notice_error(error, {:description => message})
  end
end