Authlogic::Session::Base.class_eval do
  
  private

  def secure
    return controller.request.protocol == "https://"
  end

  def httponly
    true
  end
end

require File.dirname(__FILE__) + "/../../fd_password_policy.rb"