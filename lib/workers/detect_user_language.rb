class Workers::DetectUserLanguage
  extend Resque::AroundPerform 
  @queue = 'detect_user_language'

  def self.perform(args)
    user = Account.current.users.find(args[:user_id])
    Helpdesk::DetectUserLanguage.set_user_language!(user, args[:text])
  end

end