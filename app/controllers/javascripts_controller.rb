class JavascriptsController < ApplicationController
  skip_before_filter :check_account_state
  
  def hide_announcement
    session[:announcement_hide_time] = Time.now.utc
  end
end
