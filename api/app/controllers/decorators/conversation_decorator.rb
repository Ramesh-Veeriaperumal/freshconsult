class ConversationDecorator < ApiDecorator
  attr_accessor :ticket

  delegate :body, :body_html, :full_text_html, :id, :incoming, :private, :deleted, :user_id, :support_email,
           :source, :attachments, :attachments_sharable, :schema_less_note, :cloud_files, :last_modified_timestamp,
           :last_modified_user_id, to: :record

  delegate :to_emails, :from_email, :cc_emails, :bcc_emails, :category, to: :schema_less_note, allow_nil: true

  def initialize(record, options)
    super(record)
    @ticket = options[:ticket]
    @ticket_decorator = options[:ticket_decorator]
    @send_and_set = options[:send_and_set]
    @sideload_options = options[:sideload_options] || []
    @cdn_url = Account.current.cdn_attachments_enabled?
  end

  def public_json
    construct_json.merge(source_additional_info: source_additional_info)
  end

  def send_and_set
    @send_and_set
  end

  def ticket_hash
    @ticket_decorator.to_show_hash
  end

  def conversation_json
    response_hash = {
      id: id,
      incoming: incoming,
      private: private,
      user_id: user_id,
      support_email: support_email,
      ticket_id: @ticket.display_id,
      to_emails: to_emails,
      created_at: created_at.try(:utc),
      updated_at: updated_at.try(:utc),
      attachments: attachments.map { |att| AttachmentDecorator.new(att).to_hash(@cdn_url) }
    }
    src_info = source_additional_info
    response_hash[:source_additional_info] = src_info if src_info.present?
    construct_note_body_hash.merge(response_hash)
  end

  def construct_json
    schema_less_properties = schema_less_note.try(:note_properties) || {}
    response_hash = {
      id: id,
      incoming: incoming,
      private: private,
      user_id: user_id,
      support_email: support_email,
      source: source,
      category: schema_less_note.try(:category),
      ticket_id: @ticket.display_id,
      to_emails: to_emails,
      from_email: from_email,
      cc_emails: cc_emails,
      bcc_emails: bcc_emails,
      email_failure_count: schema_less_note.failure_count,
      outgoing_failures: schema_less_properties[:errors],
      created_at: created_at.try(:utc),
      updated_at: updated_at.try(:utc),
      attachments: attachments.map { |att| AttachmentDecorator.new(att).to_hash(@cdn_url) }
    }
    construct_note_body_hash.merge(response_hash)
  end

  def to_json
    construct_json.merge(
      deleted: deleted,
      category: category,
      last_edited_at: last_modified_timestamp.try(:utc),
      last_edited_user_id: last_modified_user_id.try(:to_i),
      attachments: attachments_hash,
      cloud_files: cloud_files_hash,
      has_quoted_text: quoted_text?
    )
  end

  def default_body_hash
    {
      body: body_html,
      body_text: body
    }
  end

  def to_hash
    [to_json, freshcaller_call, tweet_hash, facebook_hash, feedback_hash, requester_hash].inject(&:merge)
  end

  def restrict_twitter_content?
    Account.current.twitter_api_compliance_enabled? && !private_api? && !channel_v2_api? && incoming && record.tweet.present?
  end

  def twitter_public_api_body_hash(body)
    {
      body: body,
      body_text: body
    }
  end

  def construct_note_body_hash
    return default_body_hash unless restrict_twitter_content?

    handle = record.tweet.twitter_handle
    twitter_user = record.user
    twitter_requester_handle_id = twitter_user.twitter_requester_handle_id || record.tweet.twitter_handle_id
    if record.tweet.tweet_type == Social::Twitter::Constants::TWITTER_NOTE_TYPE[:mention]
      tweet_body = "View the tweet at https://twitter.com/#{twitter_requester_handle_id}/status/#{record.tweet.tweet_id}"
      return twitter_public_api_body_hash(tweet_body)
    else
      dm_body_prefix = 'View the message at https://twitter.com/messages'
      if handle && twitter_user.twitter_requester_handle_id
        handle_ids = [handle.twitter_user_id.to_i, twitter_requester_handle_id.to_i]
        dm_body = "#{dm_body_prefix}/#{handle_ids.min}-#{handle_ids.max}"
      else
        dm_body = dm_body_prefix
      end
      twitter_public_api_body_hash(dm_body)
    end
  end

  def source_additional_info
    source_info = {}
    tweet = tweet_public_hash
    source_info.merge!(twitter: tweet) if tweet.present?
    source_info.merge!(facebook: FacebookPostDecorator.new(record.fb_post).public_hash) if record.fb_note? && record.fb_post.present?

    source_info.present? ? source_info : nil
  end

  def facebook_hash
    return {} unless record.fb_note? && record.fb_post.present?
    {
      fb_post: FacebookPostDecorator.new(record.fb_post).to_hash
    }
  end
  
  def freshcaller_call
    if freshcaller_enabled? && record.freshcaller_call
      call = record.freshcaller_call
      {
        freshcaller_call: {
          id: call.id,
          fc_call_id: call.fc_call_id,
          recording_status: call.recording_status
        }
      }
    else
      {}
    end
  end

  def tweet_hash
    return {} unless record.tweet? && record.tweet
    {
      tweet: {
        tweet_id: record.tweet.tweet_id.to_s,
        tweet_type: record.tweet.tweet_type,
        twitter_handle_id: record.tweet.twitter_handle_id
      }
    }
  end

  def tweet_public_hash
    return {} unless record.tweet? && record.tweet && record.tweet.twitter_handle
    handle = record.tweet.twitter_handle
    twitter_user = record.user
    twitter_requester_handle_id = twitter_user.twitter_requester_handle_id if record.incoming
    tweet_hash = {
      id: record.tweet.tweet_id > 0 ? record.tweet.tweet_id.to_s : nil,
      type: record.tweet.tweet_type,
      support_handle_id: handle.twitter_user_id.to_s,
      support_screen_name: handle.screen_name,
      requester_screen_name: Account.current.twitter_api_compliance_enabled? && !channel_v2_api? ? twitter_requester_handle_id : twitter_user.twitter_id
    }
    tweet_hash[:stream_id] = record.tweet.stream_id if channel_v2_api?
    tweet_hash
  end

  def feedback_hash
    return {} unless Account.current.new_survey_enabled? && record.feedback?
    survey_result = record.custom_survey_remark.survey_result
    {
      survey_result: {
        survey_id: survey_result.survey_id,
        agent_id: survey_result.agent_id,
        group_id: survey_result.group_id,
        rating: survey_result.custom_ratings
      }
    }
  end

  def attachments_hash
    (attachments | attachments_sharable).map { |a| AttachmentDecorator.new(a).to_hash(@cdn_url) }
  end

  def cloud_files_hash
    cloud_files.map { |cf| CloudFileDecorator.new(cf).to_hash }
  end

  def quoted_text?
    full_text_html.length > body_html.length
  end

  def requester_hash
    return {} if !@sideload_options.include?('requester') || record.user.blank?
    contact_decorator = ContactDecorator.new(record.user, {}).to_hash
    {
      requester: contact_decorator
    }
  end

  private

    def freshcaller_enabled?
      Account.current.freshcaller_enabled?
    end
end
