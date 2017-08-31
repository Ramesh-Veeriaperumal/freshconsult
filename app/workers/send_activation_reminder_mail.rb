class SendActivationReminderMail < BaseWorker
	sidekiq_options :queue => :send_activation_reminder_mail, :retry => 0, :backtrace => true, :failures => :exhausted

  def perform(args)
    args.symbolize_keys!  # converts all the keys to symbols if .to_sym can be called on them
    account = Account.current   # do have a look at the sidekiq.rb file for middlewares (client and server).
    return if account.verified? || account.ehawk_spam?   # why send a mail if already activated?
    user = account.users.find(args[:user_id])   
    reminder_count = args[:reminder_count]    # used to get the right email content. (email1, email2 etc)
    UserNotifier.deliver_activation_reminder(user, reminder_count)  # call activation reminder method in UserNotifier.
  end
end
