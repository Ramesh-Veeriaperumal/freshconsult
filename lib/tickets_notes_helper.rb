module TicketsNotesHelper
  def social_source_additional_info(source_info)
    source_info[:twitter] = tweet_info_hash if tweet.present?
    source_info[:facebook] = fb_feeds_info_hash if fb_post.present?
    source_info
  end

  def tweet_info_hash
    twt_hash = {
      tweet_id: tweet.tweet_id > 0 ? tweet.tweet_id.to_s : nil,
      type: tweet.tweet_type,
      stream_id: tweet.stream_id,
      requester_screen_name: requester_twitter_id
    }
    twt_hash.merge!(twt_handle_info)
    if tweet.is_note?
      latest_tweet_info = latest_tweet
      twt_hash[:latest_tweet_id] = latest_tweet_info[:latest_tweet_id].to_s
      twt_hash[:latest_tweet_stream_id] = latest_tweet_info[:latest_tweet_stream_id]
    end
    twt_hash
  end

  def twt_handle_info
    twitter_handle = tweet.twitter_handle
    {
      support_handle_id: twitter_handle.try(:twitter_user_id).try(:to_s),
      support_screen_name: twitter_handle.try(:screen_name),
      twitter_handle_id: twitter_handle.try(:id)
    }
  end

  def fb_feeds_info_hash
    fb_feed_hash = {
      fb_item_id: fb_post.try(:post_id).to_s,
      type: fb_post.try(:msg_type),
      requester_profile_id: requester_fb_id.to_s
    }
    fb_feed_hash.merge(fb_page_info)
  end

  def fb_page_info
    fb_page = fb_post.facebook_page

    result = {
                support_fb_page_id: fb_page.try(:page_id).try(:to_s),
                support_fb_page_name: fb_page.try(:page_name),
                fb_page_db_id: fb_page.try(:id).try(:to_s),
              }
    self.is_a?(Helpdesk::Note) ? result.merge(handler_info(fb_page)) : result
  end

  def email_source_info(header_info)
    received_at = header_info[:received_at] if header_info.present?
    {
      'received_at': received_at
    }
  end

  def email_note?
    [Account.current.helpdesk_sources.note_source_keys_by_token['email'],
     Account.current.helpdesk_sources.note_source_keys_by_token['note']].include?(source)
  end

  def email_ticket?
    email?
  end

  def handler_info(fb_page)
    parent_source_fb_post = try(:notable).try(:fb_post)
    parent_post_id = try(:fb_post).try(:parent).try(:post_id)
    handler_key = if fb_page.nil?
                    nil
                  elsif parent_source_fb_post && parent_source_fb_post.message?
                    get_thread_key(fb_page, parent_source_fb_post)
                  elsif parent_post_id
                    parent_post_id
                  else
                    parent_source_fb_post.original_post_id
                  end
    {
      fb_handler_id: handler_key
    }
  end

  def latest_tweet
    latest_tweet_info = {}
    twitter_notes = notable.notes.latest_twitter_comment
    if twitter_notes.present?
      lasest_note = twitter_notes.first
      if lasest_note.tweet.present?
        latest_tweet_info[:latest_tweet_id] = lasest_note.tweet.tweet_id
        latest_tweet_info[:latest_tweet_stream_id] = lasest_note.tweet.stream_id
      end
    end
    latest_tweet_info
  end
end
