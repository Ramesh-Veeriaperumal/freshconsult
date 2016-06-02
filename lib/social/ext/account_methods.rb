module Social::Ext::AccountMethods
  include Facebook::Constants
  include Social::Twitter::Constants

  def all_twitter_streams
    twitter_streams = self.twitter_streams.order(:created_at).all
    twitter_streams.select{|stream| stream unless stream.data[:kind] == TWITTER_STREAM_TYPE[:dm]}
  end
  
  def all_facebook_streams
    facebook_streams = self.facebook_streams.order(:created_at).all
    facebook_streams.select{|stream| stream unless stream.data[:kind] == FB_STREAM_TYPE[:dm]}
  end
  
  def random_twitter_handle
    twitter_handles.sample
  end
end
