require 'google/api_client'

class Helpdesk::DetectUserLanguage
	def self.set_user_language!(user, text)
    begin
      client = Google::APIClient.new(:application_name => "Helpkit")
      translate = client.discovered_api('translate', 'v2')
      oauth_keys = Integrations::OauthHelper.get_oauth_keys('google_oauth2')
      client.authorization.access_token = oauth_keys["consumer_token"]
      client.key = oauth_keys["api_key"]
      response = client.execute(:api_method => translate.detections.list,:parameters => {'q' => text})
      language = JSON.parse(response.body)["data"]["detections"].flatten.last["language"]
      user.language = (I18n.available_locales_with_name.map{
     		|lang,sym| sym.to_s }.include? language) ? language : user.account.language
    rescue Exception => e
      NewRelic::Agent.notice_error(e,{:custom_params =>
       {:description => "Error occoured while detecting user language using google translate"}})
      user.language = user.account.language 
    end 
    user.save
  end
end

