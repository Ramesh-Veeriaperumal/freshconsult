json.set! :notes, @notes do |note|
  json.cache! note do
    json.(note, :body, :body_html, :id, :user_id)

    json.set! :support_email, note.api_support_email

    json.set! :ticket_id, note.notable_id

    json.partial! 'shared/boolean_format', boolean_fields: { incoming: note.incoming, private: note.private }
    json.partial! 'shared/utc_date_format', item: note

    json.set! :notified_to, note.schema_less_note.to_emails
  end
  json.set! :attachments do
    json.array! note.attachments do |att|
      json.cache! att do
        json.set! :id, att.id
        json.set! :content_type, att.content_content_type
        json.set! :size, att.content_file_size
        json.set! :name, att.content_file_name
        json.set! :attachment_url, att.attachment_url_for_api
        json.partial! 'shared/utc_date_format', item: att
      end
    end
  end
end