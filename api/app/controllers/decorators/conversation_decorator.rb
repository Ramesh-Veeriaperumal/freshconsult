class ConversationDecorator < ApiDecorator
  attr_accessor :ticket

  delegate :body, :body_html, :id, :incoming, :private, :user_id, :support_email, :source, :attachments, :schema_less_note, to: :record

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
	    attachments: attachments.map do |att|
	      {
	        id: att.id,
	        content_type: att.content_content_type,
	        size: att.content_file_size,
	        name: att.content_file_name,
	        attachment_url: att.attachment_url_for_api,
	        created_at: att.created_at.try(:utc),
	        updated_at: att.updated_at.try(:utc)
	      }
	    end
	}
  end
end
