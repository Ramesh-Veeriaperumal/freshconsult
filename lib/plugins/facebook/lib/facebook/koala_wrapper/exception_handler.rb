module Facebook::KoalaWrapper::ExceptionHandler
  # status codes
  # unsupported get request error code #100
  IGNORESTATUSCODE = [100] 
  def self.included(base)
    base.extend(Facebook::KoalaWrapper::ExceptionHandler::ClassMethods)
    base.send(:include,Facebook::KoalaWrapper::ExceptionHandler::ClassMethods)
  end

  #need to refactor this code and handle the exception properly
  module ClassMethods
    def sandbox(return_value = nil)
      begin
        return_value = yield
      rescue Koala::Facebook::APIError => e
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
              UserNotifier.send_later(:deliver_notify_facebook_reauth,@fan_page.account,@fan_page)
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
          newrelic_custom_params = {
            :custom_params => {
              :error_type => e.fb_error_type,
              :error_msg => e.to_s,
              :account_id => @fan_page.account_id,
              :id => @fan_page.id
            }
          }
          NewRelic::Agent.notice_error(e, newrelic_custom_params)
          Rails.logger.debug "APIError while processing facebook - #{e.to_s}  :: account_id => #{@fan_page.account_id} :: id => #{@fan_page.id} "
        end
        return_value = false
      rescue => e
        Rails.logger.debug e.to_s
        $sqs_facebook.requeue(@feed.feed) if @intial_feed && !return_value
        SocialErrorsMailer.deliver_facebook_exception(e,@feed.feed) if @intial_feed
        NewRelic::Agent.notice_error(e)
        Rails.logger.debug "Error while processing facebook - #{e.to_s}"
        return_value = false
      end
      return return_value
    end
  end

end
