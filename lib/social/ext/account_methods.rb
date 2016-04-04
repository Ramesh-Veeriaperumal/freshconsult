module Social::Ext::AccountMethods
  include Social::Twitter::Constants

  def all_social_streams
    twitter_streams = self.twitter_streams.find(:all, :order => :created_at)
    twitter_streams.select{|stream| stream unless stream.data[:kind] == TWITTER_STREAM_TYPE[:dm]}
  end
  
  def random_twitter_handle
    twitter_handles.sample
  end
end
