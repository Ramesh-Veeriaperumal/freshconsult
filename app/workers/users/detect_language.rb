class Users::DetectLanguage < BaseWorker

  sidekiq_options :queue => :detect_user_language, 
                  :retry => 0, 
                  :backtrace => true, 
                  :failures => :exhausted

  def perform(args)
    args.symbolize_keys!
    return unless args[:user_id].present?
    user = Account.current.all_users.find_by_id(args[:user_id])
    Helpdesk::DetectUserLanguage.set_user_language!(user, 
                                    args[:text]) if user.present?
  end
end
