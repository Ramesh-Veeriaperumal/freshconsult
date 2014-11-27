module Mobile::Actions::Social
  include Mobile::Constants

  private
  def render_mobile_response
    @all_screen_names = @all_handles.map {|handle| handle.screen_name }
    meta_data_hash = { :streams => @streams, :custom_streams => @custom_streams,
                       :thumb_avatar_urls => @thumb_avatar_urls, :meta_data => @meta_data,
                       :visible_handles => @visible_handles, :reply_handles => @reply_handles,
                       :all_screen_names => @all_screen_names } if params["send_meta_data"]
    render :json => { :sorted_feeds => @sorted_feeds ,
                      :first_feed_ids => @first_feed_ids,
                      :last_feed_ids => @last_feed_ids,
                      :reply_privilege => current_user.can_reply_ticket
                      }.merge!(meta_data_hash || {})
  end

  def render_twitter_mobile_response
    render :json => { :sorted_feeds => @sorted_feeds,
                      :max_id => @next_results,
                      :since_id => @refresh_url,
                      :reply_privilege => current_user.can_reply_ticket }
  end

  def is_mobile_meta_request?
    params.has_key?(:send_meta_data)
  end
end
