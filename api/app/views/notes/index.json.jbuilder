json.array! @notes do |note|
  json.cache! note do
    json.(note, :body, :body_html, :id, :incoming, :private, :user_id, :support_email)
    
    json.set! :ticket_id, note.notable_id
    
    json.partial! 'shared/utc_date_format', item: note
    
    json.set! :notified_to, note.to_emails
    
    json.set! :attachments do
      json.array! note.attachments do |att|
        json.cache! att do
          json.set! :id, att.id
          json.set! :content_type, att.content_content_type
          json.set! :file_size, att.content_file_size
          json.set! :file_name, att.content_file_name
          json.partial! 'shared/utc_date_format', item: att
        end
      end
    end
  
  end
end
