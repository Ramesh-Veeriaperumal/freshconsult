json.(@note, :body, :body_html, :id, :user_id, :from_email, :cc_emails, :bcc_emails)

json.set! :ticket_id, @note.notable_id
json.set! :replied_to, @note.to_emails

json.set! :attachments do
  json.array! @note.attachments do |att|
    json.set! :id, att.id
    json.set! :content_type, att.content_content_type
    json.set! :file_size, att.content_file_size
    json.set! :file_name, att.content_file_name
    json.partial! 'shared/utc_date_format', item: att
  end
end

json.partial! 'shared/utc_date_format', item: @note
