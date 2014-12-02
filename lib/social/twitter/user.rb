class Social::Twitter::User

  include Social::Util
  include Social::Twitter::ErrorHandler
  include Social::Twitter::Constants

  attr_accessor :name, :screen_name, :description, :location, :prof_img_url, :time_zone, :followers_count

  def initialize(user_obj)
    @name               = user_obj.name
    @screen_name        = user_obj.screen_name
    @description        = user_obj.description
    @location           = user_obj.location
    @prof_img_url       = user_obj.profile_image_url_https
    @time_zone          = user_obj.time_zone
    @followers_count    = user_obj.followers_count
  end

  def self.fetch(handle, screen_name)
    twt_sandbox(handle) do
      wrapper = TwitterWrapper.new handle
      twitter = wrapper.get_twitter
      users = twitter.users([screen_name])
      user = Social::Twitter::User.new(users.first)
    end
  end  

  def self.get_followers(handle, screen_name)
    return if screen_name.blank?
    twt_sandbox(handle) do
      twitter = TwitterWrapper.new(handle).get_twitter
      follower_ids = []
      options = {}
      FOLLOWERS_FETCH_COUNT.times do
        followers = twitter.follower_ids(screen_name, options)
        follower_ids << followers.attrs[:ids]
        break if followers.attrs[:next_cursor] == 0
        options = {:cursor => followers.attrs[:next_cursor]}
      end
      follower_ids.flatten
    end
  end 
  
end
