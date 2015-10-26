Authlogic::Session::Base.class_eval do
  
  ActionController::Metal.send(:include, AbstractController::Callbacks )
  ActionController::Metal.send(:include, Authlogic::ControllerAdapters::RailsAdapter::RailsImplementation)

  private

  def secure
    return controller.request.protocol == "https://"
  end

  def httponly
    true
  end
end

require File.dirname(__FILE__) + "/../../fd_password_policy.rb"
