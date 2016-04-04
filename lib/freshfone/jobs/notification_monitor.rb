class Freshfone::Jobs::NotificationMonitor
  extend Resque::AroundPerform
  
  @queue = "freshfone_default_queue"
  
  def self.perform(args)
    Rails.logger.debug "NotificationMonitor for account :: #{Account.current.id} :: Call :: #{args[:freshfone_call]}"
    p args

    freshfone_call = Account.current.freshfone_calls.find(args[:freshfone_call])
    
    if freshfone_call.present? && freshfone_call.meta.present?
      failed_call = freshfone_call.meta.pinged_agents.detect{ |agent| agent[:call_sid].blank? }    
      unless failed_call.blank?
        notifier_params = {
          :recipients => FreshfoneConfig['ops_alert']['mail']['to'],
          :from       => FreshfoneConfig['ops_alert']['mail']['from'],
          :subject    => "Conference Notification failure",
          :message    => "Account :: #{Account.current.id} <br/> Call:: #{freshfone_call.id} 
                          <br/> Pinged agents :: #{freshfone_call.meta.pinged_agents.inspect}
                          <br/> Parent call :: #{freshfone_call.is_root?}"
        }
        FreshfoneNotifier.freshfone_email_template(Account.current, notifier_params)
      end
    end
  end
end