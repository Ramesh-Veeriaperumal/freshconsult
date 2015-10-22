Authlogic::Session::Base.class_eval do

  private

  def secure
    return controller.request.protocol == "https://"
  end

  def httponly
    true
  end
end
