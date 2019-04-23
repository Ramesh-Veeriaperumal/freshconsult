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

  def fetch_account_id_if_exist?(data)
    account_id = redis_key_exists?(FB_MAPPING_ENABLED) && fetch_account_id(data)
    return account_id if account_id.present?
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
    account_id = fetch_account_id_if_exist?(data)
    if account_id
      @account_id = account_id
    else
      select_fb_shard_and_account(page_id) do |account|
        @account_id = account.id
      end
    end
  end

  def select_shard_without_fb_mapping(page_id, data, &block)
    account_id = fetch_account_id_if_exist?(data)
    if account_id
      select_shard_and_account(account_id) do |account|
        yield(account)
      end
    else
      select_fb_shard_and_account(page_id) do |account|
        yield(account)
      end
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

  def smart_filter_info(num)
    {
      "smart_filter_response" => num
    }
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

  def construct_media_url_hash(account, item, tweet, oauth_credential)
    media_url_hash = {}
    begin
      media_array = tweet.media
      photo_url_hash = {}
      media_array.each do |media|
        if(media.class.name == TWITTER_MEDIA_PHOTO || media.class.name == TWITTER_MEDIA_ANIMATEDGIF)
          url = media.media_url_https.to_s
          headers = SimpleOAuth::Header.new(:GET, url, {}, oauth_credential)
          file_name = url[url.rindex('/')+1, url.length]
          options = {
            :file_content => open(url, "Authorization" => headers.to_s),
            :filename => file_name,
            :content_type => get_content_type(file_name),
            :content_size => 1000
          }

          image_attachment = Helpdesk::Attachment.create_for_3rd_party(account,item, options, 1, 1, false)
          if image_attachment.present? && image_attachment.content.present?
            photo_url_hash[media.url.to_s] = image_attachment.inline_url
          end
        end
      end
      media_url_hash[:photo] = photo_url_hash if photo_url_hash.present?
    rescue => e
      Rails.logger.error("Exception while attaching media content to ticket Exception: #{e.class} Exception Message: #{e.message}")
    end
    media_url_hash
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

  def tweet_body(tweet)
    tweet[:long_object].try(:[], "body") || tweet[:body]
  end

  def consumer_app_details(handle)
    handle.present? && !handle.new_record? && euc_migrated_handle?(handle) ?
      [TwitterConfig::CLIENT_ID_FALLBACK, TwitterConfig::CLIENT_SECRET_FALLBACK] :
      [TwitterConfig::CLIENT_ID, TwitterConfig::CLIENT_SECRET]
  end

  def euc_migrated_handle?(handle)
    # EUC POD with the handle migrated from the EU data center.
    Account.current.launched?(:euc_migrated_twitter) && ismember?(EU_TWITTER_HANDLES, "#{Account.current.id}:#{handle.twitter_user_id}")
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
