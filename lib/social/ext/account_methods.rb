module Social::Ext::AccountMethods
  include Social::Twitter::Constants

  def all_social_streams
    twitter_streams = self.twitter_streams.find(:all, :order => :created_at)
    twitter_streams.map{|stream| stream unless stream.data[:kind] == STREAM_TYPE[:dm]}.compact
  end
  
  def random_twitter_handle
    twitter_handles.sample
  end
end
