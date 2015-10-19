json.set! :notes, @notes do |note|
  json.cache! CacheLib.compound_key(note, note.note_body, params) do
    json.extract! note, :body, :body_html, :id, :user_id, :support_email, :created_at, :updated_at

    json.set! :ticket_id, @item.display_id

    json.partial! 'shared/boolean_format', boolean_fields: { incoming: note.incoming, private: note.private }

    json.set! :notified_to, note.schema_less_note.try(:to_emails)
  end
  json.set! :attachments do
    json.array! note.attachments do |att|
      json.cache! CacheLib.key(att, params) do
        json.set! :id, att.id
        json.set! :content_type, att.content_content_type
        json.set! :size, att.content_file_size
        json.set! :name, att.content_file_name
        json.extract! att, :created_at, :updated_at
      end
      json.set! :attachment_url, att.attachment_url_for_api
    end
  end
end
