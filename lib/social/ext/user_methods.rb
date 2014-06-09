module Social::Ext::UserMethods
  
  def visible_twitter_streams
    streams = is_agent ? accessible_twitter_streams : []
  end

  def visible_social_streams
    streams = is_agent ? accessible_social_streams : []
  end
  
  private
  
    def accessible_social_streams
      accessible_stream_ids = Account.current.accesses.user_accessible_items_via_group('Social::Stream', self).map(&:accessible_id)
      social_streams = Account.current.social_streams.find(:all, :conditions => { :id => accessible_stream_ids })
    end 
    
    def accessible_twitter_streams
      social_streams = accessible_social_streams
      twitter_streams = social_streams.select {|stream| stream.type == 'Social::TwitterStream' }
    end 
end