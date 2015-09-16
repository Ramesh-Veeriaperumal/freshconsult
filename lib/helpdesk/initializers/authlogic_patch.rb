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
