class ConversationDecorator < ApiDecorator
  attr_accessor :ticket

  delegate :body, :body_html, :id, :incoming, :private, :user_id, :support_email, :source, :attachments, :schema_less_note, :fb_post, to: :record

  delegate :to_emails, :from_email, :cc_emails, :bcc_emails, to: :schema_less_note, allow_nil: true

  def initialize(record, options)
    super(record)
    @ticket = options[:ticket]
  end

  def attachments_hash
    attachments.map { |a| AttachmentDecorator.new(a).to_hash }
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
      ticket_id: @ticket.display_id,
      to_emails: to_emails,
      from_email: from_email,
      cc_emails: cc_emails,
      bcc_emails: bcc_emails,
      created_at: created_at.try(:utc),
      updated_at: updated_at.try(:utc),
      attachments: attachments_hash
    }
  end

  def to_hash
    [construct_json, freshfone_call, tweet_hash, facebook_hash].inject(&:merge)
  end
  
  def facebook_hash
    return {} unless fb_post.present? 
    { fb_post: FacebookPostDecorator.new(fb_post).to_hash }
  end

  def freshfone_call
    call = record.freshfone_call
    return {} unless call.present? && call.recording_url.present? && call.recording_audio
    {
      id: call.id,
      duration: call.call_duration,
      recording: AttachmentDecorator.new(call.recording_audio).to_hash
    }
  end

  def tweet_hash
    return {} unless record.tweet? && record.tweet
    {
      tweet: record.tweet.attributes.slice('tweet_id', 'tweet_type', 'twitter_handle_id')
    }
  end
    
end
