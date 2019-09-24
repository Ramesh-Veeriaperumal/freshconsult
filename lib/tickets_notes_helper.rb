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
    twt_hash[:latest_tweet_id] = latest_tweet_id.to_s if tweet.is_note?
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
    [Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['email'],
     Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['note']].include?(source)
  end

  def email_ticket?
    email?
  end

  def handler_info(fb_page)
    parent_source_fb_post = try(:notable).try(:fb_post)
    handler_key = if fb_page.nil?
                    nil
                  elsif parent_source_fb_post && parent_source_fb_post.message?
                    get_thread_key(fb_page, parent_source_fb_post)
                  else
                    parent_source_fb_post.original_post_id
                  end
    {
      fb_handler_id: handler_key
    }
  end

  def latest_tweet_id
    twitter_notes = notable.notes.latest_twitter_comment
    if twitter_notes.present?
      lasest_note = twitter_notes.first
      return lasest_note.tweet.tweet_id if lasest_note.tweet.present?
    end
  end
end
