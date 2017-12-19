class ConversationDecorator < ApiDecorator
  attr_accessor :ticket

  delegate :body, :body_html, :full_text_html, :id, :incoming, :private, :deleted, :user_id, :support_email,
           :source, :attachments, :attachments_sharable, :schema_less_note, :cloud_files, :last_modified_timestamp,
           :last_modified_user_id, to: :record

  delegate :to_emails, :from_email, :cc_emails, :bcc_emails, :category, to: :schema_less_note, allow_nil: true

  def initialize(record, options)
    super(record)
    @ticket = options[:ticket]
    @sideload_options = options[:sideload_options] || []
  end

  def construct_json
    {
      body: body_html,
      body_text: body,
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
      created_at: created_at.try(:utc),
      updated_at: updated_at.try(:utc),
      attachments: attachments.map { |att| AttachmentDecorator.new(att).to_hash }
    }
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

  def to_hash
    [to_json, freshfone_call, freshcaller_call, tweet_hash, facebook_hash, feedback_hash, requester_hash].inject(&:merge)
  end

  def facebook_hash
    return {} unless record.fb_note? && record.fb_post.present?
    {
      fb_post: FacebookPostDecorator.new(record.fb_post).to_hash
    }
  end

  def freshfone_call
    if freshfone_enabled?
      call = record.freshfone_call
      return {} unless call.present? && call.recording_url.present? && call.recording_audio
      {
        freshfone_call: {
          id: call.id,
          duration: call.call_duration,
          recording: AttachmentDecorator.new(call.recording_audio).to_hash
        }
      }
    else
      {}
    end
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

  def quoted_text?
    full_text_html.length > body_html.length
  end

  def requester_hash
    return {} unless @sideload_options.include?('requester')
    contact_decorator = ContactDecorator.new(record.user, {}).to_hash
    {
      requester: contact_decorator
    }
  end

  private

    def freshfone_enabled?
      Account.current.freshfone_enabled?
    end

    def freshcaller_enabled?
      Account.current.freshcaller_enabled?
    end
end
