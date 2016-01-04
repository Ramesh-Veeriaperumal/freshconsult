require 'google/api_client'

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
    begin
      client = Google::APIClient.new(:application_name => "Helpkit")
      translate = client.discovered_api('translate', 'v2')
      oauth_keys = Integrations::OauthHelper.get_oauth_keys('google_oauth2')
      client.authorization.access_token = oauth_keys["consumer_token"]
      client.key = oauth_keys["api_key"]
      response = client.execute(:api_method => translate.detections.list,:parameters => {'q' => text})
      response_body = JSON.parse(response.body)
      language = response_body["data"]["detections"].flatten.last["language"] if (response_body and response_body["data"])

      # Hack for hypenated language codes
      if language
        language = GOOGLE_LANGUAGES.has_key?(language.to_sym) ? GOOGLE_LANGUAGES[language.to_sym] : language
        user.language = (I18n.available_locales_with_name.map{
       		|lang,sym| sym.to_s }.include? language) ? language : user.account.language
      else
        user.language = user.account.language 
      end
    rescue Exception => e
      NewRelic::Agent.notice_error(e,{:custom_params =>
       {:description => "Error occoured while detecting user language using google translate"}})
      user.language = user.account.language 
    end 
    user.save
  end
end

