class Resque::FreshdeskBase

  def self.before_enqueue_add_account_and_user(*args)
    args[0][:current_account_id] = Account.current.id if Account.current
    args[0][:current_user_id] = User.current.id if User.current
  end

  def self.before_perform_set_account_and_user(*args)
    Account.reset_current_account
    User.reset_current
    job_account = args[0]["current_account_id"]
    job_user = args[0]["current_user_id"]
    Account.find(job_account).make_current if job_account
    User.find(job_user).make_current if job_user
    TimeZone.set_time_zone
  end

end