class Social::Twitter::User

  include Social::Util
  include Social::Twitter::ErrorHandler

  attr_accessor :name, :screen_name, :description, :location, :prof_img_url, :time_zone

  def initialize(user_obj)
    @name         = user_obj.name
    @screen_name  = user_obj.screen_name
    @description  = user_obj.description
    @location     = user_obj.location
    @prof_img_url = user_obj.profile_image_url_https
    @time_zone    = user_obj.time_zone
  end

  def self.fetch(handle, screen_name)
    twt_sandbox(handle) do
      wrapper = TwitterWrapper.new handle
      twitter = wrapper.get_twitter
      users = twitter.users([screen_name])
      user = Social::Twitter::User.new(users.first)
      return user
    end
  end
end
