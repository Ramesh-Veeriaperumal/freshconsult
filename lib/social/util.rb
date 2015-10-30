module Social::Util

  include Gnip::Constants
  include Social::Constants

  def select_shard_and_account(account_id)
    begin
      Sharding.select_shard_of(account_id) do
        account = Account.find_by_id(account_id)
        account.make_current if account
        account = Account.current
        yield(account)
      end
    rescue ActiveRecord::RecordNotFound => e
      Rails.logger.debug "Could not find account with id #{account_id}"
      custom_params = {
        :account_id => account_id,
        :description => "Could not find valid account id in DbUtil"
      }
      NewRelic::Agent.notice_error(e, :custom_params => custom_params)
    end
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

  def fd_info(notable, user)
    link = notable.nil? ? nil : helpdesk_ticket_link(notable)
    user = user.nil? ? nil : user.id
    {
      :fd_link => link,
      :fd_user => user
    }
  end
  
  def remove_utf8mb4_char(ticket_content)
    "".tap do |out_str|
      for i in (0...ticket_content.length)
        char = ticket_content[i]
        char = " " if char.ord > 65535
        out_str << char
      end
      out_str.squeeze!(" ")
      out_str << "Not given" if (!ticket_content.blank? and out_str.blank?)
    end
  end

end
