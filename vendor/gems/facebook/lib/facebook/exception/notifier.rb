module Facebook
  module Exception
    module Notifier
    
      include Social::Dynamo::UnprocessedFeed    
      
      def raise_newrelic_error(error)
        Rails.logger.error error.inspect
        Rails.logger.debug "Error while processing facebook - #{@exception.to_s}:::#{@exception.backtrace.join('\n')}"
        NewRelic::Agent.notice_error(@exception, error)
      end
      
      def update_error_and_notify(error)
        error_updated = false
        if @fan_page.last_error.nil?
          @fan_page.update_attributes({
                                  :enable_page     => false,
                                  :reauth_required => true,
                                  :last_error      => error
          })
          UserNotifier.send_later(:deliver_notify_facebook_reauth, @fan_page, locale_object: Account.current.admin_email)
          error_updated = true
        end
        error.merge!({
          :error_updated => error_updated
        })
        notify_error(error)
      end
      
      def notify_error(error)
        raise_sns_notification(error[:error_msg][0..50], error)
        insert_facebook_feed(@fan_page.page_id, (Time.now.to_f*1000).to_i, @raw_obj) if @raw_obj
      end
      
      def error_params
        {
          :error_code     => @exception.fb_error_code,
          :error_type     => @exception.fb_error_type, 
          :error_msg      => @exception.fb_error_message,
          :account_id     => @fan_page.account_id,
          :facebook_page  => @fan_page.page_id,
          :fb_page_id     => @fan_page.id
        }  
      end
      
      def page_info
        {:page_id => @fan_page.id, :account_id => @fan_page.account_id}
      end
      
      private      
      def raise_sns_notification(subject, message)
        message ||= {}
        message.merge!(:environment => Rails.env)
        topic = SNS["social_notification_topic"]
        DevNotification.publish(topic, subject, message.to_json)
      end

    end
  end
end
