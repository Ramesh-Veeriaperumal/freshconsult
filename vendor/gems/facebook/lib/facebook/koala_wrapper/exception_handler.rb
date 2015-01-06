module Facebook::KoalaWrapper::ExceptionHandler
  
  def self.included(base)
    base.extend(Facebook::KoalaWrapper::ExceptionHandler::ClassMethods)
    base.send(:include,Facebook::KoalaWrapper::ExceptionHandler::ClassMethods)
  end

  #need to refactor this code and handle the exception properly
  module ClassMethods
    AUTH_ERROR               = 190
    AUTH_SUB_CODES           = [458, 459, 460, 463, 464, 467]
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
      rescue Koala::Facebook::APIError => exception
        error_params = construct_error_and_raise(exception)
        
        #Exception due to change of password - Authorisation error
        if exception.fb_error_code == AUTH_ERROR
          subcode = exception.fb_error_subcode if exception.respond_to?(:fb_error_subcode)
          if ((subcode and AUTH_SUB_CODES.include?(subcode)) or ERROR_MESSAGES.any?{|k,v| error_params[:error_msg].include?(v)})
            update_error_and_notify(error_params)
          end
          
        #Exception due to change of permission given to the app
        elsif !exception.http_status.blank? and exception.http_status.between?(HTTP_STATUS_CLIENT_ERROR.first,  HTTP_STATUS_CLIENT_ERROR.last)
          
          #Too Many Requests (Ratelimit exception)
          if exception.fb_error_code == APP_RATE_LIMIT or exception.fb_error_code == USER_RATE_LIMIT
            $sqs_facebook.requeue(@feed.feed) if @intial_feed
          elsif exception.fb_error_code.between?(PERMISSION_ERROR.first,  PERMISSION_ERROR.last)
            update_error_and_notify(error_params)
          end
        
        #Exception due to change of permission for the user who authorised the app
        elsif !exception.http_status.blank? and exception.http_status.between?(HTTP_STATUS_SERVER_ERROR.first, HTTP_STATUS_SERVER_ERROR.last)
          
          if exception.fb_error_code.between?(PERMISSION_ERROR.first, PERMISSION_ERROR.last)
            update_error_and_notify(error_params)
          end
        end
        
      rescue => exception
        #construct_error_and_raise(exception)
        Rails.logger.error exception.inspect
        Rails.logger.error exception.message
        NewRelic::Agent.notice_error(exception, {:page_id => @fan_page.id, :account_id => @fan_page.account_id})
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
