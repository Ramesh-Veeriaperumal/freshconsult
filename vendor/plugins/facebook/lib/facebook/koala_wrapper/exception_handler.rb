module Facebook::KoalaWrapper::ExceptionHandler
  
  def self.included(base)
    base.extend(Facebook::KoalaWrapper::ExceptionHandler::ClassMethods)
    base.send(:include,Facebook::KoalaWrapper::ExceptionHandler::ClassMethods)
  end

  #need to refactor this code and handle the exception properly
  module ClassMethods
    AUTH_ERROR               = 190
    AUTH_SUB_CODES           = [458, 460, 463, 467]
    HTTP_STATUS_CLIENT_ERROR = [400, 499]
    HTTP_STATUS_SERVER_ERROR = [500, 599]
    APP_RATE_LIMIT           = 4
    USER_RATE_LIMIT          = 17
    PERMISSION_ERROR         = [200, 299]
    ERROR_MESSAGES           = {:permission_error => "manage_pages",  :auth_error => "impersonate" }
    
    def sandbox(return_value = nil)
      exception = nil
      begin
        return_value = yield
        @fan_page = @fan_page || @fb_page
        if e.fb_error_type == 4 #error code 4 is for api limit reached
          @fan_page.update_attribute(:last_error,e.to_s)

          #requeue if api limit is reached
          $sqs_facebook.requeue(@feed.feed) if @intial_feed && !return_value

          Rails.logger.debug "API Limit reached - #{e.to_s} :: account_id => #{@fan_page.account_id} :: id => #{@fan_page.id} "
          newrelic_custom_params =  {
            :custom_params => {
              :error_type => e.fb_error_type,
              :error_msg => e.to_s
            }
          }
          NewRelic::Agent.notice_error(e, newrelic_custom_params)
        else
          if @fan_page && !@fan_page.reauth_required
            error_strings = Facebook::Worker::FacebookMessage::ERROR_MESSAGES
            if error_strings.any?{|k,v| e.to_s.include?(v)}
              @fan_page.update_attributes({
                                            :enable_page => false,
                                            :reauth_required => true,
                                            :last_error => e.to_s
              })

              #send mail to the account admin if needed
              UserNotifier.send_later(:notify_facebook_reauth,@fan_page.account,@fan_page)
              if @intial_feed && !return_value
                Facebook::Core::Util.add_to_dynamo_db(@fan_page.page_id, (Time.now.to_f*1000).to_i, @intial_feed)
              end
            else
              if @intial_feed && !(e.respond_to?(:fb_error_code) && 
                Facebook::KoalaWrapper::ExceptionHandler::IGNORESTATUSCODE.include?(e.fb_error_code))
                SocialErrorsMailer.deliver_facebook_exception(e,@feed.feed) if @feed 
              end
            end
          end
        end
        
      rescue => exception
        construct_error_and_raise(exception)
      end
      
      return_value = false unless exception.nil?
      return return_value
      
    end
    
    def construct_error_and_raise(e)
      error_params = {
        :error_code     => e.fb_error_code,
        :error_type     => e.fb_error_type, 
        :error_msg      => e.fb_error_message,
        :account_id     => @fan_page.account_id,
        :facebook_page  => @fan_page.page_id,
        :fb_page_id     => @fan_page.id
      }  
      Rails.logger.debug error_params
      Rails.logger.debug "Error while processing facebook - #{e.to_s}:::#{e.backtrace.join('\n')}"
      NewRelic::Agent.notice_error(e, error_params)
      error_params
    end
    
    def update_error_and_notify(error_params)
      error_updated = false
      if @fan_page.last_error.nil?
        @fan_page.update_attributes({
                                :enable_page     => false,
                                :reauth_required => true,
                                :last_error      => error_params
        })
        UserNotifier.send_later(:deliver_notify_facebook_reauth, @fan_page.account, @fan_page)
        error_updated = true
      end
      error_params.merge!({
        :error_updated => error_updated
      })
      raise_sns_notification(error_params[:error_msg][0..50], error_params)
      Facebook::Core::Util.add_to_dynamo_db(@fan_page.page_id, (Time.now.to_f*1000).to_i, @intial_feed) if @intial_feed
    end
    
    def raise_sns_notification(subject, message)
      message = {} unless message
      message.merge!(:environment => Rails.env)
      topic = SNS["social_notification_topic"]
      DevNotification.publish(topic, subject, message.to_json)
    end
    
  end

end
