module HttpProxyMethods

  include MemcacheKeys

  def replace_placeholders(domain, rest_url, user_current)
    SAFE_URLS.each do |item|
      domain_pattern = Regexp.new "^https?:\/\/#{item[:domain]}$"
      if(domain_pattern.match domain)
        item[:placeholders].each do |placeholder, m|
          rest_url = rest_url.gsub(placeholder, send(m, rest_url))
        end
      end
    end
    rest_url
  end

  def surveymonkey_apikey(rest_url)
    MemcacheKeys.fetch('surveymonkey_consumer_secret') {
      key_hash = Integrations::OauthHelper.get_oauth_keys('surveymonkey')
      key_hash['consumer_secret']
    }
  end
  
  SAFE_URLS =	[{  :domain => 'api\.surveymonkey\.net',
                  :placeholders => {"smonkey_secret" => :surveymonkey_apikey}
               }]

end
