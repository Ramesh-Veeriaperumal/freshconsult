module Social::Util

  include Gnip::Constants
  include Social::Constants

  def select_shard_and_account(account_id, &block)
    begin
      Sharding.select_shard_of(account_id) do
        account = Account.find(account_id)
        account.make_current if account
        account = Account.current
        yield(account) if block_given?
      end
    rescue ActiveRecord::RecordNotFound, ShardNotFound => e
      Rails.logger.debug "#{e.inspect} -- #{account_id}"
      custom_params = {
        :account_id => account_id,
        :description => "#{e.inspect}"
      }
      NewRelic::Agent.notice_error(e, :custom_params => custom_params)
    end
  end
  
  def select_fb_shard_and_account(page_id, &block)
    mapping = Social::FacebookPageMapping.find_by_facebook_page_id(page_id)
    account_id = mapping ? mapping.account_id : nil
    if account_id
      select_shard_and_account(account_id, &block)
    else
      Rails.logger.error "FacebookPageMapping not present for #{page_id}"
      yield(nil) if block_given?
    end
  end
  
  def get_tweet_text(tweet_type, ticket, twt_text)
    if tweet_type.eql?"mention"
      error_message, tweet_body = validate_tweet(twt_text, "#{ticket.latest_twitter_comment_user}") 
    else
      error_message, tweet_body = validate_tweet(twt_text, nil, false) 
    end
    [error_message, tweet_body]
  end
  
  def validate_tweet(tweet, twitter_id, is_reply = true)
    twt_text = (is_reply and !tweet.include?(twitter_id)) ? "#{twitter_id} #{tweet}" : tweet
    tweet_length = twt_text.gsub(URL_REGEX, TWITTER_URL_LENGTH).length; 
    length = twitter_id.nil? ? Social::Tweet::DM_LENGTH : Social::Tweet::TWEET_LENGTH
    twitter_error_message = t('twitter.not_valid') if (tweet_length > length)
    [twitter_error_message, twt_text]
  end

  def helpdesk_ticket_link(item)
    return nil if item.nil? or item.id.nil? #if the ticket/note save failed or we requeue the feed
    if item.is_a?(Helpdesk::Ticket)
      link = "#{item.display_id}"
    elsif item.is_a?(Helpdesk::Note)
      ticket = item.notable
      link = "#{ticket.display_id}#note#{item.id}"
    end
  end

  def notify_social_dev(subject, message)
    message = {} unless message
    message.merge!(:environment => Rails.env)
    topic = SNS["social_notification_topic"]
    DevNotification.publish(topic, subject, message.to_json) unless (Rails.env.development? or Rails.env.test?)
  end

  def select_valid_date(time, table="feeds")
    retention = TABLES[table][:retention_period]
    reference_date = Time.parse(TABLES[table][:db_reference_date])

    days = ((time - reference_date)/retention).to_i #Number of days since reference date
    date = reference_date + retention*days #Valid Date
    date.strftime("%Y%m%d")
  end
  
  def fb_feed_info(fd_item, user, feed)
    koala_feed = feed.koala_feed
    attributes = fd_info(fd_item, user)
    
    attributes.merge!({:type           => feed.type })    
    attributes.merge!({:parent_comment => koala_feed.parent[:id]}) if feed.instance_of?(Facebook::Core::ReplyToComment)
    attributes.merge!({:likes          => koala_feed.likes}) if koala_feed.instance_of?(Facebook::KoalaWrapper::Post)
    attributes
  end

  def fd_info(notable, user)
    link = notable.nil? ? nil : helpdesk_ticket_link(notable)
    user = user.nil? ? nil : user.id
    {
      :fd_link => link,
      :fd_user => user
    }
  end
  
  def dynamo_hash_and_range_key(stream_id)
    {
      :stream_id  => stream_id,
      :account_id => Account.current.id
    }
  end
  
  def social_revamp_enabled?
    Account.current.features?(:social_revamp)
  end

end
