module Helpdesk::LanguageDetection
  include Redis::RedisKeys
  include Redis::OthersRedis

  def text_for_detection body
    text = body[0..600]
    text.squish.split.first(500).join(' ')
  end

  def language_detection user_id, account_id, text
    Users::DetectLanguage.perform_async({:user_id => user_id, :text => text})
  end 
end
