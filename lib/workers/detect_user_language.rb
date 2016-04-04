class Workers::DetectUserLanguage
  extend Resque::AroundPerform 
  @queue = 'detect_user_language'

  def self.perform(args)
    user = Account.current.all_users.find(args[:user_id])
    Helpdesk::DetectUserLanguage.set_user_language!(user, args[:text]) if user
  end

end