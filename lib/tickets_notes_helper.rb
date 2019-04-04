module TicketsNotesHelper

  def source_additional_info_hash
    source_info = {}
    source_info[:twitter] = tweet_info_hash if tweet.present?
    source_info.presence
  end

  def tweet_info_hash
    twt_hash = {
      'tweet_id': tweet.tweet_id > 0 ? tweet.tweet_id.to_s : nil,
      'type': tweet.tweet_type,
      'stream_id': tweet.stream_id
    }
    twt_hash.merge(twt_handle_info(tweet))
  end

  def twt_handle_info(tweet)
    twitter_handle = tweet.twitter_handle
    {
      'support_handle_id': twitter_handle.twitter_user_id.to_s,
      'support_screen_name': twitter_handle.screen_name,
      'requester_screen_name': requester_twitter_id,
      'twitter_handle_id': twitter_handle.id
    }
  end
end
