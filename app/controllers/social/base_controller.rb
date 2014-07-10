class Social::BaseController < ApplicationController
  include ApplicationHelper
  include Social::BaseHelper
  
  def twitter_avatar_urls(size)
    @all_handles.inject({}) do |hash, handle| 
      hash["#{handle.screen_name}"] = s3_twitter_avatar(handle, size)
      hash
    end
  end
end