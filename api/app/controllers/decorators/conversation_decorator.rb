class ConversationDecorator < ApiDecorator
  attr_accessor :ticket

  delegate :body, :body_html, :full_text_html, :id, :incoming, :private, :deleted, :user_id, :support_email, 
            :source, :attachments, :attachments_sharable, :schema_less_note, :cloud_files, :last_modified_timestamp, 
            :last_modified_user_id, to: :record

  delegate :to_emails, :from_email, :cc_emails, :bcc_emails, to: :schema_less_note, allow_nil: true

  def initialize(record, options)
    super(record)
    @ticket = options[:ticket]
  end

  def construct_json
    {
      body: body_html,
      body_text: body,
      id: id,
      deleted: deleted,
      incoming: incoming,
      private: private,
      user_id: user_id,
      support_email: support_email,
      source: source,
      ticket_id: @ticket.display_id,
      to_emails: to_emails,
      from_email: from_email,
      cc_emails: cc_emails,
      bcc_emails: bcc_emails,
      created_at: created_at.try(:utc),
      updated_at: updated_at.try(:utc),
      last_edited_at: last_modified_timestamp.try(:utc),
      last_edited_by: last_modified_user_id.try(:to_i),
      attachments: attachments_hash,
      cloud_files: cloud_files_hash,
      has_quoted_text: has_quoted_text?
    }
  end

  def to_hash
    [construct_json, freshfone_call, tweet_hash, facebook_hash, feedback_hash].inject(&:merge)
  end

  def facebook_hash
    return {} unless record.fb_note? && record.fb_post.present?
    {
      fb_post: FacebookPostDecorator.new(record.fb_post).to_hash
    }
  end

  def freshfone_call
    call = record.freshfone_call
    return {} unless call.present? && call.recording_url.present? && call.recording_audio
    {
      freshfone_call: {
        id: call.id,
        duration: call.call_duration,
        recording: AttachmentDecorator.new(call.recording_audio).to_hash
      }
    }
  end

  def tweet_hash
    return {} unless record.tweet? && record.tweet
    {
      tweet: record.tweet.attributes.slice('tweet_id', 'tweet_type', 'twitter_handle_id')
    }
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
    (attachments | attachments_sharable).map { |a| AttachmentDecorator.new(a).to_hash }
  end

  def cloud_files_hash
    cloud_files.map { |cf| CloudFileDecorator.new(cf).to_hash }
  end

  def has_quoted_text?
    full_text_html.length > body_html.length
  end

end
