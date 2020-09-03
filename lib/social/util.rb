module Social::Util

  include Gnip::Constants
  include Social::Constants
  include Redis::OthersRedis

  def select_shard_and_account(account_id, &block)
    begin
      Sharding.select_shard_of(account_id) do
        account = Account.find(account_id)
        account.make_current if account
        account = Account.current
        yield(account) if block_given?
      end
    rescue AccountBlocked => e
      Rails.logger.debug "Social Feed :: Account blocked :: #{account_id} :: description :: #{e.inspect}"
    rescue ActiveRecord::RecordNotFound, ShardNotFound, DomainNotReady => e
      Rails.logger.debug "#{e.inspect} -- #{account_id}"
      custom_params = {
        :account_id => account_id,
        :description => "#{e.inspect}"
      }
      NewRelic::Agent.notice_error(e, :custom_params => custom_params)
    end
  end

  def fetch_account_id(data)
    return if data.blank?
    if data.is_a?(Hash) && data['account_id'].present? && data['account_id'].to_i.nonzero?
      data['account_id']
    elsif !data.is_a?(Hash) && data.to_i.nonzero? # !data.is_a?(Hash) to avoid exception
      data
    end
  end

  def set_account_id(page_id, data)
    @account_id = fetch_account_id(data)
  end

  def select_shard_without_fb_mapping(page_id, data, &block)
    account_id = fetch_account_id(data)
    if account_id
      select_shard_and_account(account_id) do |account|
        yield(account)
      end
    else
      Rails.logger.error "Issues with account info for facebook page::#{page_id}"
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
    tweet.gsub!(NEW_LINE_WITH_CARRIAGE_RETURN, NEW_LINE_CHARACTER)
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

  def fetch_media_url(account, item, twt, options)
    @inline_attachments = []
    @photo_url_hash = {}
    if twt.respond_to?('media?') && twt.media?
      construct_media_url_hash_direct_message(account, item, twt, options[:oauth_credential])
    elsif (twt.is_a? Hash) && tweet_media_content_exists?(twt)
      construct_media_url_hash_tweets(account, item, twt, options[:oauth_credential])
    end
  end

  def construct_media_url_hash_direct_message(account, item, tweet, oauth_credential)
    media_url_hash = {}
    media = tweet.media[0]
    begin
      if media.class.name == TWITTER_MEDIA_PHOTO || media.class.name == TWITTER_MEDIA_ANIMATED_GIF
        url = media.media_url_https.to_s
        create_attachments(account, item, url, oauth_credential)
        if @photo_url_hash.present?
          media_url_hash[:photo] = @photo_url_hash
          media_url_hash[:twitter_url] = media.url.to_s
        end
      end
    rescue StandardError => e
      Rails.logger.error("Error attaching media from twitter feed, tweet : #{tweet.id} : Exception: #{e.class} : Exception Message: #{e.message}")
    end
    item.inline_attachments = @inline_attachments.compact
    media_url_hash
  end

  def construct_media_url_hash_tweets(account, item, tweet, oauth_credential)
    media_url_hash = {}
    media_array = tweet[:twitter_extended_entities]['media']
    begin
      media_array.each do |media|
        next unless media['type'] == TWEET_MEDIA_PHOTO || media['type'] == TWEET_MEDIA_ANIMATED_GIF
        url = media['media_url_https']
        create_attachments(account, item, url, oauth_credential)
      end
      if @photo_url_hash.present?
        media_url_hash[:photo] = @photo_url_hash
        media_url_hash[:twitter_url] = media_array[0]['url']
      end
    rescue StandardError => e
      Rails.logger.error("Error attaching media from twitter feed, tweet : #{tweet.id} : Exception: #{e.class} : Exception Message: #{e.message}")
    end
    item.inline_attachments = @inline_attachments.compact
    media_url_hash
  end

  def create_attachments(account, item, url, oauth_credential)
    headers = SimpleOAuth::Header.new(:GET, url, {}, oauth_credential)
    file_name = url[url.rindex('/') + 1, url.length]
    options = {
      file_content: open(url, 'Authorization' => headers.to_s),
      filename: file_name,
      content_type: get_content_type(file_name),
      content_size: 1000
    }
    image_attachment = Helpdesk::Attachment.create_for_3rd_party(account, item, options, 1, 1, false)
    if image_attachment.present? && image_attachment.content.present?
      @photo_url_hash[url] = image_attachment.inline_url
      @inline_attachments.push(image_attachment)
    end
  end

  def get_content_type(basename)
    case basename
    when /\.gif$/i
      'image/gif'
    when /\.jpe?g/i
      'image/jpeg'
    when /\.png$/i
      'image/png'
    when /\.tiff?/i
      'image/tiff'
    else
      'application/octet-stream'
    end
  end

  def tokenize(message)
    message.to_s.tokenize_emoji.gsub(EMOJI_UNICODE_REGEX," ")
  end

  def social_enabled?
    settings = Account.current.account_additional_settings.additional_settings
    settings.blank? || settings[:enable_social].nil? || settings[:enable_social]
  end

  def handles_associated?
    !Account.current.twitter_handles_from_cache.blank?
  end

  def tweet_body(tweet)
    tweet[:long_object].try(:[], "body") || tweet[:body]
  end

  def consumer_app_details(handle)
    [TwitterConfig::CLIENT_ID, TwitterConfig::CLIENT_SECRET]
  end
  
  def get_oauth_credential(twt_handle)
    client_id, client_secret = consumer_app_details(twt_handle)
    { consumer_key: client_id,
      consumer_secret: client_secret,
      token: twt_handle.access_token,
      token_secret: twt_handle.access_secret }
  end

  def tweet_media_content_exists?(twt)
    twt[:twitter_extended_entities].present? && twt[:twitter_extended_entities]['media'].present?
  end

  def post_command_to_central(command, client, *args)
    payload_hash = command_payload(command, client, *args)
    msg_id = generate_msg_id(payload_hash)
    Rails.logger.info "Command from Helpkit, Command: #{command}, Msg_id: #{msg_id}"
    Channel::CommandWorker.perform_async({ payload: payload_hash }, msg_id)
  end

  def command_payload(command_name, client, *args)
    schema = default_command_schema(client, command_name)
    schema.merge!(safe_send("#{command_name}_payload", *args))
  end

  def generate_msg_id(payload)
    Digest::MD5.hexdigest(payload.to_s)
  end

  def monitor_app_permission_payload
    { data: {}, context: {} }
  end

  def activate_handle_payload(handle)
    {
      data: {
        source_account_id: Account.current.account_additional_settings.additional_settings[:clone][:account_id],
        twitter_handle_id: handle.id,
        twitter_user_id: handle.twitter_user_id
      },
      context: {}
    }
  end
end
