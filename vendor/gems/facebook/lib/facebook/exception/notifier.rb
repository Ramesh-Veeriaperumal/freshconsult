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
        notify_fb_mailer(nil, error, error[:error_msg][0..50])
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

      def notify_fb_mailer(error, params = nil, subject = nil)
        return if Rails.env.development? || Rails.env.test?

        SocialErrorsMailer.deliver_facebook_exception(error, params, subject)
      end
    end
  end
end
