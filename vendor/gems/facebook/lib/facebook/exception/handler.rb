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
            
            if auth_error?
              update_error_and_notify(error_params)
                         
            elsif client_error?
              if app_rate_limit_exceeded?
                throttle_processing unless app_rate_limit_reached?
                notify_error(error_params)
              elsif page_rate_limit_exceeded?
                throttle_fb_page_processing(@fan_page.account_id, @fan_page.page_id)
                notify_error(error_params)
                raise_newrelic_error(error_params)
              elsif user_rate_limit_exceeded?
                throttle_page_processing(@fan_page.page_id)
                error_params.merge!({:api_hit_count => fb_api_hit_count(@fan_page.page_id)})
                update_error_and_notify(error_params)
              elsif permission_error?
                IGNORED_ERRORS.include?(@exception.fb_error_code) ? 
                    raise_sns_notification(error_params[:error_msg][0..50], error_params) : 
                    update_error_and_notify(error_params)
              else
                raise_newrelic_error(error_params)
              end
            
            elsif server_error?
              if permission_error?
                update_error_and_notify(error_params)
              else
                Sqs::Message.new("{}").requeue(JSON.parse(@raw_obj)) if (@raw_obj && @exception.response_body.downcase.include?(SERVICE_UNAVAILABLE))
                raise_sns_notification("Server Error", {:error => "Server Error", :exception => @exception})
              end
            else
              raise_newrelic_error(error_params)
            end
            
          rescue => @exception
            raise_newrelic_error(page_info)
          ensure
            @fan_page.log_api_hits
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

        def page_rate_limit_exceeded?
          @exception.fb_error_code == PAGE_RATE_LIMIT_ERROR_CODE
        end
        
        def permission_error?
          !@exception.fb_error_code.blank? && @exception.fb_error_code.between?(PERMISSION_ERROR.first,  PERMISSION_ERROR.last) && @exception.fb_error_message.include?(PERMISSION_MSG)
        end
        
      end
      
    end
  end
end
