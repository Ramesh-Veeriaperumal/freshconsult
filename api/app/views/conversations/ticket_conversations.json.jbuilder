json.array! @ticket_conversations do |conversation|
  # Not caching the body as it has a bigger impact for conversations having huge body
  json.set! :body, conversation.body_html
  json.set! :body_text, conversation.body

  json.cache! CacheLib.compound_key(conversation, ApiConstants::CACHE_VERSION[:v2], params) do
    json.extract! conversation, :id, :incoming, :private, :user_id, :support_email, :source

    json.set! :ticket_id, @ticket.display_id
    json.set! :to_emails, conversation.schema_less_note.try(:to_emails)
    json.set! :from_email, conversation.schema_less_note.try(:from_email)
    json.set! :cc_emails, conversation.schema_less_note.try(:cc_emails)
    json.set! :bcc_emails, conversation.schema_less_note.try(:bcc_emails)

    json.partial! 'shared/utc_date_format', item: conversation
  end
  json.set! :attachments do
    json.array! conversation.attachments do |att|
      json.cache! att do
        json.set! :id, att.id
        json.set! :content_type, att.content_content_type
        json.set! :size, att.content_file_size
        json.set! :name, att.content_file_name
        json.partial! 'shared/utc_date_format', item: att
      end
      json.set! :attachment_url, att.attachment_url_for_api
    end
  end
end
