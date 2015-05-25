module Social::Twitter::ErrorHandler

  def self.included(base)
    base.extend(ClassMethods)
    base.send(:include, ClassMethods)
  end

  module ClassMethods
    
    include Social::Util

    def twt_sandbox(handle, timeout = TwitterConfig::TWITTER_TIMEOUT)
      
      #overide timeout according the the env timeout values
      timeout = TwitterConfig::TWITTER_TIMEOUT if TwitterConfig::TWITTER_TIMEOUT > timeout
      exception = nil
      
      @social_error_msg = nil      
      begin
        @sandbox_handle = handle
        return_value = false

        if handle.blank?
          @social_error_msg = "#{I18n.t('social.streams.twitter.feeds_blank')}"
        elsif handle.reauth_required?
          @social_error_msg = "#{I18n.t('social.streams.twitter.handle_auth_error')}"
        end

        Timeout.timeout(timeout) do
          return_value = yield unless @social_error_msg
        end

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

      rescue Twitter::Error::NotFound => exception
        @social_error_msg = "#{I18n.t('social.streams.twitter.wrong_call')}" #Unfavoriting what has not been fav already
        notify_error(exception)

      rescue Twitter::Error => exception
        @social_error_msg = "#{I18n.t('social.streams.twitter.client_error')}"
        notify_error(exception)
      
      rescue Timeout::Error => exception
        @social_error_msg = "#{I18n.t('social.streams.twitter.client_error')}"
        error = caller[0..11]
        notify_error(error, "Twitter Timeout Exception")      
      end

      return [@social_error_msg, return_value]
    end

    def notify_error(error, subject = nil)
      subject = "Twitter REST API Exception" if subject.nil?
      if @sandbox_handle
        error_params = { :account_id => @sandbox_handle.account_id ,
                         :handle_id => @sandbox_handle.id,
                         :exception_type => error
                         }
        notify_social_dev(subject, error_params)
      end
    end

  end
end
