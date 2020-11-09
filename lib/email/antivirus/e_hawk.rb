module Email::Antivirus::EHawk

    include Redis::RedisKeys
    include Redis::OthersRedis
    include Redis::PortalRedis

    def increase_ehawk_spam_score_for_account(spam_score, account, subject, additional_info)
      mail_recipients = ['mail-alerts@freshdesk.com', 'helpdesk@abusenoc.freshservice.com']
      FreshdeskErrorsMailer.error_email(nil, {:domain_name => Account.current.full_domain}, nil, {
                :subject => subject,
                :recipients => mail_recipients,
                :additional_info => {:info => additional_info}
              })
      signup_params = (get_signup_params || {}).merge({"api_response" => {}})
      signup_params["api_response"]["status"] = spam_score
      set_others_redis_key(signup_params_key,signup_params.to_json)
      account.conversion_metric.update_attribute(:spam_score, spam_score) if account.conversion_metric
      increment_portal_cache_version
    end

    def signup_params_key
      ACCOUNT_SIGN_UP_PARAMS % {:account_id => Account.current.id}
    end

    def get_signup_params
      signup_params_json = get_others_redis_key(signup_params_key)
      return nil if signup_params_json.blank? ||  signup_params_json == "null"
      JSON.parse(get_others_redis_key(signup_params_key))
    end

    def increment_portal_cache_version
      return if get_portal_redis_key(PORTAL_CACHE_ENABLED) === "false"
      key = PORTAL_CACHE_VERSION % { :account_id => Account.current.id }
      increment_portal_redis_version key
    end
end