module Forum::CheckSpamContent

  include Redis::RedisKeys
  include Redis::OthersRedis
  include Redis::PortalRedis
  include Solution::Constants
  include Email::Antivirus::EHawk

  def check_post_description_for_spam(post_id, topic_id)
    post = Account.current.posts.find_by_id(post_id) #find post
    return false if post.blank?
    spam_status = check_post_content_for_spam(post.body)
    if spam_status
      subject = "Detected suspicious forum post created in : Account:#{Account.current.id}, Account state : #{Account.current.subscription.state}, Post ID : #{post_id}"
      additional_info = "Suspicious forum post in Account ##{Account.current.id} with ehawk_reputation_score: #{Account.current.ehawk_reputation_score} , Post id : #{post_id} , Topic id : #{topic_id}"
      increase_ehawk_spam_score_for_account(4,Account.current, subject, additional_info)
    end
    return spam_status
  end

  def check_topic_title_for_spam(topic_id)
    topic = Account.current.topics.find_by_id(topic_id) #find topic
    return false if topic.blank?
    spam_status = check_post_content_for_spam(topic.title)
    if spam_status
      subject = "Detected suspicious forum topic created in Account:#{Account.current.id}"
      additional_info = "Suspicious forum topic created in Account ##{Account.current.id} with ehawk_reputation_score: #{Account.current.ehawk_reputation_score} , Topic id : #{topic_id}"
      increase_ehawk_spam_score_for_account(4,Account.current, subject, additional_info)
    end
    return spam_status
  end

  def check_post_content_for_spam(post_content)
    forum_post_spam_regex_value = get_others_redis_key(FORUM_POST_SPAM_REGEX)
    forum_post_spam_regex = forum_post_spam_regex_value.present? ? Regexp.compile(forum_post_spam_regex_value, true) : Regexp.compile(AccountConstants::DEFAULT_FORUM_POST_SPAM_REGEX, true)
    phone_number_spam_regex = Regexp.new($redis_others.perform_redis_op("get", PHONE_NUMBER_SPAM_REGEX), "i")
    post_content_spam_char_regex = Regexp.new($redis_others.perform_redis_op("get", CONTENT_SPAM_CHAR_REGEX))

    stripped_post_content = post_content.gsub(Regexp.new(Solution::Constants::CONTENT_ALPHA_NUMERIC_REGEX), "")
    return true if (stripped_post_content=~ phone_number_spam_regex).present?

    desc_un_html_lines = post_content.split("\n")
    spam_content = false
    desc_un_html_lines.each do |desc_line|
      spam_content = true and break if ((desc_line =~ forum_post_spam_regex).present? || (desc_line =~ post_content_spam_char_regex).present?)
    end
    return spam_content
  end

 end 