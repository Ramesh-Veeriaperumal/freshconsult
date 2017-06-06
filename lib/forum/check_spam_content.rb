module Forum::CheckSpamContent

  include Redis::RedisKeys
  include Redis::OthersRedis
  include Redis::PortalRedis

  def check_post_description_for_spam(post_id, topic_id)
    post = Account.current.posts.find_by_id(post_id) #find post
    return false if post.blank?
    spam_status = check_post_content_for_spam(post.body)
    increase_ehawk_spam_score_for_account(4, topic_id, post_id) if spam_status
    return spam_status
  end

  def check_topic_title_for_spam(topic_id)
    topic = Account.current.topics.find_by_id(topic_id) #find topic
    return false if topic.blank?
    spam_status = check_post_content_for_spam(topic.title)
    increase_ehawk_spam_score_for_account(4, topic_id) if spam_status
    return spam_status
  end

  def check_post_content_for_spam(post_content)
    forum_post_spam_regex_value = get_others_redis_key(FORUM_POST_SPAM_REGEX)
    forum_post_spam_regex = forum_post_spam_regex_value.present? ? Regexp.compile(forum_post_spam_regex_value, true) : Regexp.compile(AccountConstants::DEFAULT_FORUM_POST_SPAM_REGEX, true)
    phone_number_spam_regex = Regexp.new($redis_others.perform_redis_op("get", PHONE_NUMBER_SPAM_REGEX), "i")

    desc_un_html_lines = post_content.split("\n")
    spam_content = false
    desc_un_html_lines.each do |desc_line|
      spam_content = true and break if ((desc_line =~ forum_post_spam_regex).present? || (desc_line =~ phone_number_spam_regex).present?)
    end
    return spam_content
  end
   
  def increase_ehawk_spam_score_for_account(spam_score, topic_id, post_id = nil)
    if post_id.present?
      subject = "Detected suspicious forum post created in Account:#{Account.current.id}"
      additional_info = "Suspicious forum post in Account ##{Account.current.id} with ehawk_reputation_score: #{Account.current.ehawk_reputation_score} , Post id : #{post_id} , Topic id : #{topic_id}"
      notify_spam_detection(subject, additional_info)
    else
      subject = "Detected suspicious forum topic created in Account:#{Account.current.id}"
      additional_info = "Suspicious forum topic created in Account ##{Account.current.id} with ehawk_reputation_score: #{Account.current.ehawk_reputation_score} , Topic id : #{topic_id}"
      notify_spam_detection(subject, additional_info)
    end
    signup_params = (get_signup_params || {}).merge({"api_response" => {}})
    signup_params["api_response"]["status"] = spam_score
    set_others_redis_key(signup_params_key,signup_params.to_json)
    Account.current.conversion_metric.update_attribute(:spam_score, spam_score) if Account.current.conversion_metric
    increment_portal_cache_version
    Rails.logger.info ":::::: Forum spam content encountered - increased spam reputation for article ##{post_id} in account ##{Account.current.id}  :::::::"
  end

  def notify_spam_detection(subject , additional_info)
    mail_recipients = ["mail-alerts@freshdesk.com","noc@freshdesk.com"]
    FreshdeskErrorsMailer.error_email(nil, {:domain_name => Account.current.full_domain}, nil, {
            :subject => subject, 
            :recipients => mail_recipients,
            :additional_info => {:info => additional_info}
          })
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