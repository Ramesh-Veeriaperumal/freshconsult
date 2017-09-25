module Helpdesk::LanguageDetection
  include Redis::RedisKeys
  include Redis::OthersRedis

  def text_for_detection body
    text = body[0..200]
    text.squish.split.first(15).join(" ")
  end

  def language_detection user_id, account_id, text
    if redis_key_exists?(DETECT_USER_LANGUAGE_SIDEKIQ_ENABLED)
      Users::DetectLanguage.perform_async({:user_id => user_id, 
                                           :text => text})
    else
      Resque::enqueue(Workers::DetectUserLanguage, 
                      {:user_id => user_id, 
                       :text => text, 
                       :account_id => account_id})
    end
  end 
end
