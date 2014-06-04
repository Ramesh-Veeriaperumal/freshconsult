module Social::Twitter::ErrorHandler

  def self.included(base)
    base.extend(ClassMethods)
    base.send(:include, ClassMethods)
  end

  module ClassMethods
    
    include Social::Util

    def twt_sandbox(handle)
      exception = nil
      begin
        @sandbox_handle = handle
        return_value = false
        if handle.blank?
          @social_error_msg = "#{I18n.t('social.streams.twitter.feeds_blank')}"
          puts "*************** Blank Handle *****************"
        elsif handle.reauth_required?
          @social_error_msg = "#{I18n.t('social.streams.twitter.handle_auth_error')}"
          puts "************** Reauth Required ***************"
        end
        return_value = yield unless @social_error_msg
      rescue Twitter::Error::Unauthorized => exception
        @sandbox_handle.state = Social::TwitterHandle::TWITTER_STATE_KEYS_BY_TOKEN[:reauth_required]
        @sandbox_handle.last_error = exception.to_s
        @sandbox_handle.save
        @social_error_msg = "#{I18n.t('social.streams.twitter.handle_auth_error')}"
        notify_error(exception)
      rescue Twitter::Error::AlreadyPosted => exception
        @social_error_msg = "#{I18n.t('social.streams.twitter.already_tweeted')}"
        notify_error(exception)
      rescue Twitter::Error::AlreadyRetweeted => exception
        @social_error_msg = "#{I18n.t('social.streams.twitter.already_retweeted')}"
        notify_error(exception)
      rescue Twitter::Error::TooManyRequests => exception
        @social_error_msg = "#{I18n.t('social.streams.twitter.rate_limit_reached')}"
        notify_error(exception)
      rescue Twitter::Error::Forbidden => exception
        @social_error_msg = "#{I18n.t('social.streams.twitter.client_error')}"
        notify_error(exception)
      rescue Twitter::Error::GatewayTimeout => exception
        @social_error_msg = "GatewayTimeout Error"
        notify_error(exception)
      rescue Twitter::Error => exception
        @social_error_msg = "#{I18n.t('social.streams.twitter.client_error')}"
        notify_error(exception)
      #ensure
        #notify_error(exception) if @social_error_msg and exception
      end
      return [return_value, @social_error_msg]
    end

    def notify_error(error)
      puts "^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^"
      puts error.inspect
      puts error.backtrace.join(",")
      puts "^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^"
      if @sandbox_handle
        error_params = { :account_id => @sandbox_handle.account_id , 
                          :handle_id => @sandbox_handle.id, 
                          :exception_type => error 
        }
        puts error_params.inspect
        notify_social_dev("Twitter REST API Exception", error_params)
      end
    end
  end
end
