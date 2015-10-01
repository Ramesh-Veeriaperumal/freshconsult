json.array! @notes do |note|
  json.cache! CacheLib.compound_key(note, note.note_body, params) do
    json.extract! note, :body, :body_html, :id, :incoming, :private, :user_id, :support_email

    json.set! :ticket_id, @ticket.display_id

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
