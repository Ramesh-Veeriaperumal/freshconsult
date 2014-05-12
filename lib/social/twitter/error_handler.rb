module Social::Twitter::ErrorHandler

  def self.included(base)
    base.extend(ClassMethods)
    base.send(:include, ClassMethods)
  end

  module ClassMethods

    def twt_sandbox(handle)
      exception = nil
      begin
        @sandbox_handle = handle
        return_value = false

        if handle.blank?
          @social_error_msg = "#{I18n.t('social.streams.twitter.feeds_blank')}"
        elsif handle.reauth_required?
          @social_error_msg = "#{I18n.t('social.streams.twitter.handle_auth_error')}"
        end
        return_value = yield unless @social_error_msg
      rescue Twitter::Error::Unauthorized => exception
        @sandbox_handle.state = Social::TwitterHandle::TWITTER_STATE_KEYS_BY_TOKEN[:reauth_required]
        @sandbox_handle.last_error = exception.to_s
        @sandbox_handle.save
        @social_error_msg = "#{I18n.t('social.streams.twitter.handle_auth_error')}"
      rescue Twitter::Error::TooManyRequests => exception
        @social_error_msg = "#{I18n.t('social.streams.twitter.rate_limit_reached')}"
      rescue Twitter::Error::Forbidden => exception
        @social_error_msg = "#{I18n.t('social.streams.twitter.forbidden_error')}"
      rescue Twitter::Error::ClientError => exception
        @social_error_msg = "#{I18n.t('social.streams.twitter.client_error')}"
      rescue Twitter::Error => exception
        @social_error_msg = "#{I18n.t('social.streams.twitter.client_error')}"
      ensure
        notify_error(exception) if @social_error_msg and exception
      end
      return [return_value, @social_error_msg]
    end

    def notify_error(error)
      puts error.inspect
      puts error.backtrace.join(",")
      if @sandbox_handle
        error_params = { :account_id => @sandbox_handle.account_id , :handle_id => @sandbox_handle.id }
        puts error_params.inspect
        NewRelic::Agent.notice_error(error, {:custom_params => error_params })
      end
    end
  end
end
