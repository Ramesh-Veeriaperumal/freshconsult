require 'google/api_client'
include Social::Util

class Helpdesk::DetectUserLanguage

  # https://developers.google.com/translate/v2/using_rest#language-params
  GOOGLE_LANGUAGES = {
    :ja      => "ja-JP",
    :nb      => "nb-NO",
    :pt      => "pt-PT",
    :ru      => "ru-RU",
    :sv      => "sv-SE",
    :"zh-TW" => "zh-CN"
  }

  def self.set_user_language!(user, text)
    language, time_taken = language_detect(text)

    # Hack for hypenated language codes
    if language
      log_result("successful", user.email, time_taken, language)
      language = GOOGLE_LANGUAGES.has_key?(language.to_sym) ? GOOGLE_LANGUAGES[language.to_sym] : language
      user.language = (I18n.available_locales_with_name.map{
        |lang,sym| sym.to_s }.include? language) ? language : user.account.language
    else
      log_result("failed", user.email, time_taken)
      user.language = user.account.language 
    end
    user.save
  end

  def self.language_detect(text)
    time_taken = Benchmark.realtime {
      client = Google::APIClient.new(:application_name => "Helpkit")
      translate = client.discovered_api('translate', 'v2')
      oauth_keys = Integrations::OauthHelper.get_oauth_keys('google_oauth2')
      client.authorization = nil
      client.key = oauth_keys["api_key"]
      start_time = Time.now.utc
      @language_response = client.execute(:api_method => translate.detections.list,
                                          :parameters => {'q' => text})
    }
    language = nil
    response_body = JSON.parse(@language_response.body)
    if response_body && response_body["data"]
      language = response_body["data"]["detections"].flatten.last["language"]
      Rails.logger.info "google::language_detection language : #{language} for text : #{text}"
    else
      raise "Response: #{response_body.to_json}"
    end
  rescue Exception => e
    log_errors("Error detecting language using GoogleAPI:", "Account_ID: #{Account.current.id} Text: #{text}, Error: #{e.message} ", e)
  ensure
    return [language, time_taken]
  end

  def self.log_result(result, email, time, lang=nil)
    Rails.logger.debug "Language detection #{result} #{email} #{time} #{lang}"
  end

  def self.log_errors(title, message, error)
    Rails.logger.info "#{title} #{message}"
    notify_social_dev(title, {:msg => message}) 
    NewRelic::Agent.notice_error(error, {:description => "#{title} #{message}"})
  end 
end
