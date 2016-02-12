module Facebook
  module Exception
    module Handler
  
      def self.included(base)
        base.extend(Facebook::Exception::Handler::ClassMethods)
        base.send(:include,Facebook::Exception::Handler::ClassMethods)
      end

      module ClassMethods
        
        include Redis::RedisKeys
        include Facebook::RedisMethods
        include Facebook::Exception::Notifier
        include Facebook::Exception::Constants
             
        def sandbox(raw_obj = nil)
          @exception = nil
          @raw_obj   = raw_obj
          
          begin
            return_value = yield
          rescue Koala::Facebook::APIError => @exception
            raise_newrelic_error(error_params)
            
            if auth_error?
              update_error_and_notify(error_params)
                         
            elsif client_error?
              if app_rate_limit_exceeded?
                throttle_fb_feed_processing 
                notify_error(error_params)
              elsif user_rate_limit_exceeded?
                update_error_and_notify(error_params)
              elsif permission_error?
                IGNORED_ERRORS.include?(@exception.fb_error_code) ? 
                    raise_sns_notification(error_params[:error_msg][0..50], error_params) : 
                    update_error_and_notify(error_params)
              end
            
            elsif server_error?
              if permission_error?
                update_error_and_notify(error_params)
              else
                Sqs::Message.new("{}").requeue(@raw_obj)
                raise_sns_notification("Server Error", @exception)
              end
            else
              raise_sns_notification(error_params[:error_msg][0..50], error_params)
            end
            
          rescue => @exception
            raise_newrelic_error(page_info)
          end
          
          @exception.nil? ? return_value : false
              
        end
        
        
        private       
        def auth_error?
          if @exception.fb_error_code == AUTH_ERROR
            subcode = @exception.fb_error_subcode if @exception.respond_to?(:fb_error_subcode)
            subcode and AUTH_SUB_CODES.include?(subcode) or ERROR_MESSAGES.any?{|k,v| error_params[:error_msg].include?(v)}
          end
        end
        
        def client_error?
          !@exception.http_status.blank? and @exception.http_status.between?(HTTP_STATUS_CLIENT_ERROR.first,  HTTP_STATUS_CLIENT_ERROR.last)
        end
        
        def server_error?
          !@exception.http_status.blank? and @exception.http_status.between?(HTTP_STATUS_SERVER_ERROR.first, HTTP_STATUS_SERVER_ERROR.last)
        end
        
        def app_rate_limit_exceeded?
          @exception.fb_error_code == APP_RATE_LIMIT
        end
        
        def user_rate_limit_exceeded?
          @exception.fb_error_code == USER_RATE_LIMIT
        end
        
        def permission_error?
          !@exception.fb_error_code.blank? and @exception.fb_error_code.between?(PERMISSION_ERROR.first,  PERMISSION_ERROR.last)
        end
        
      end
      
    end
  end
end
