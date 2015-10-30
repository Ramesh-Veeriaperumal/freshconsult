json.set! :notes, @notes do |note|
  # Not caching the body as it has a bigger impact for notes having huge body
  json.set! :body, note.body
  json.set! :body_html, note.body_html

  json.cache! CacheLib.key(note, params) do
    json.extract! note, :id, :user_id, :support_email

    json.set! :ticket_id, @item.display_id

    json.partial! 'shared/boolean_format', boolean_fields: { incoming: note.incoming, private: note.private }
    json.partial! 'shared/utc_date_format', item: note

    json.set! :notified_to, note.schema_less_note.try(:to_emails)
  end
  json.set! :attachments do
    json.array! note.attachments do |att|
      json.cache! CacheLib.key(att, params) do
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
