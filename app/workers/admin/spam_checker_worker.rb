module Admin
  class SpamCheckerWorker < BaseWorker

    sidekiq_options :queue => :email_notification_spam_queue, 
                    :retry => 0, 
                    :backtrace => true, 
                    :failures => :exhausted
    def perform args
      begin
        content = args["content"]
        request_params = {
           :user_id => args["user_id"],
           :remote_ip => args["remote_ip"],
           :user_agent => args["user_agent"],
           :referrer => args["referrer"],
           :email_notification_type => args["notification_type"]
        }
        spam_checker = Spam::SpamCheck.new
        result = spam_checker.check_spam_content(content, request_params)
        resolve_spam if spam_checker.is_spam?(result)
      rescue Exception => e
        msg = "Exception in checking spam : "+
              "Account id: #{Account.current.id}, User id:: #{args['user_id']}, #{e.message}" 
        Rails.logger.error "#{msg} : #{e.message} - #{e.backtrace}"        
        NewRelic::Agent.notice_error(e, {:custom_params => {:args => args }})
        raise e
      end
    end
        
    def resolve_spam
      # TO DO
    end
  end
end