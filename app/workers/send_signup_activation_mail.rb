class SendSignupActivationMail < BaseWorker

  sidekiq_options :queue => :send_signup_activation_mail, :retry => 2, :backtrace => true, :failures => :exhausted

  def perform(args)
    args.symbolize_keys!
    Sharding.select_shard_of(args[:account_id]) do 
      account = Account.find(args[:account_id]).make_current
      user = account.users.find(args[:user_id]) 
      user.reset_perishable_token!
      UserNotifier.deliver_admin_activation(user)
      account.delete_account_activation_job_status   
    end
  end
end