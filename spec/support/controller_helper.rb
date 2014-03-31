module ControllerHelper

  def log_in(user)
    user.should_not be_nil
    session = UserSession.create!(user)
    session.should be_valid
    session.save
  end  
end