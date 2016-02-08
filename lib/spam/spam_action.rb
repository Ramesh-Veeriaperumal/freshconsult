module Spam::SpamAction
  include Redis::RedisKeys
  include Redis::OthersRedis  

  def build_content(subject, message)
    "Subject : #{subject}  Message :  #{message}"
  end

  def validate_template_content(subject, message, notification_type)
    content = build_content(subject, message)
    Admin::SpamCheckerWorker.perform_async({
      :content           => content,
      :user_id           => User.current.id,
      :remote_ip         => request.remote_ip,
      :user_agent        => request.env['HTTP_USER_AGENT'],
      :referrer          => request.referrer,
      :notification_type => notification_type
    })
  end

  def detect_spam_action
    return if account_whitelisted?
    @errors ||= []
    email_domain = current_user.email.split("@").last.downcase
    
    if domain_check(email_domain)
      if (3.days.ago < current_account.created_at) && has_less_open_tickets?
        Rails.logger.debug "User : #{current_user.id} / account : #{current_account.id} is prevented from updating email notification template." + "Params used are :email domain => #{email_domain}"
        @errors << t("email_notification.spam_error")
      elsif (7.days.ago < current_account.created_at)
        auto_redirect_check(2)
      else
        auto_redirect_check(5)
      end 
    end
  end

  def auto_redirect_check(limit)
    Rails.logger.debug "Inside auto_redirect_check : limit - #{limit}"
    subject, message = extract_subject_and_message
    return if ((!subject.present?) && (!message.present?))
    detect_auto_redirect_links(subject, message, limit)    
  end
  
  def detect_auto_redirect_links(subject, message, limit)
    @errors ||= []
    content = build_content(subject, message)
    if ::Spam::SpamCheck.new.has_more_redirection_links?(content, limit)
      Rails.logger.debug "Account #{current_account} has more redirect links found in the content #{content}. DB update won't work"
      @errors << t("email_notification.spam_error")
    end
  end

  def template_spam_check
    subject, message = extract_subject_and_message
    return if ((!subject.present?) && (!message.present?))
    notifi = @email_notification || @dynamic_notification.email_notification
    notification_type = notifi.notification_type
    Rails.logger.debug("Inside template_spam_check :: Subject : #{subject} == Message : #{message} == Notification Type : #{notification_type}")
    validate_template_content(subject, message, notification_type)
  end

  def account_whitelisted?
    acc_id = current_account.id
    !get_others_redis_key(notification_whitelisted_key(acc_id)).nil? || !$spam_watcher.get("#{acc_id}-").nil?
  end
  
  def notification_whitelisted_key(account)
    SPAM_NOTIFICATION_WHITELISTED_DOMAINS_EXPIRY % {:account_id => account}
  end
  
  def domain_check(email_domain)
    ismember?(SPAM_USER_EMAIL_DOMAINS, email_domain)
  end
  
  def has_less_open_tickets?
    current_account.tickets.limit(11).count < 10
  end
end
