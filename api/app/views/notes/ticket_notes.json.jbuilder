json.array! @notes do |note|
  # Not caching the body as it has a bigger impact for notes having huge body
  json.set! :body, note.body
  json.set! :body_html, note.body_html

  json.cache! CacheLib.compound_key(note, ApiConstants::CACHE_VERSION[:v2], params) do
    json.extract! note, :id, :incoming, :private, :user_id, :support_email, :source

    json.set! :ticket_id, @ticket.display_id
    json.set! :to_emails, note.schema_less_note.try(:to_emails)
    json.set! :from_email, note.schema_less_note.try(:from_email)
    json.set! :cc_emails, note.schema_less_note.try(:cc_emails)
    json.set! :bcc_emails, note.schema_less_note.try(:bcc_emails)

    json.partial! 'shared/utc_date_format', item: note
  end
  json.set! :attachments do
    json.array! note.attachments do |att|
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
