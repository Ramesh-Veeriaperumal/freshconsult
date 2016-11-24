module Admin::Freshfone::RequestFeature
  include Redis::RedisKeys
  include Freshfone::SubscriptionsUtil

  def request_freshfone
    email_params = {
      :subject => "Phone Request - #{current_account.name}",
      :from => current_user.email,
      :cc => current_account.admin_email,
      :message => "Request to enable the phone channel in your Freshdesk account.",
      :type => "Request Freshfone Feature"
    }
    FreshfoneNotifier.send_later(
        :deliver_freshfone_request_template,
        current_account, current_user, email_params)
    FreshfoneNotifier.send_later(
        :deliver_freshfone_ops_notifier,
        current_account,
        message: "Phone Activation Requested From Trial For Account ::#{current_account.id}",
        recipients: ["freshfone-ops@freshdesk.com","pulkit@freshdesk.com"]) if in_trial_states?
  end

  def add_freshfone_request_to_redis
    set_key(activation_key, true, 1.week.seconds)
  end

  def activation_key
    FRESHFONE_ACTIVATION_REQUEST % { :account_id => current_account.id }
  end
end
