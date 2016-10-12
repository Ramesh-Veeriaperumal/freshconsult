json.extract! @note, :id, :from_email, :cc_emails, :bcc_emails

json.set! :body, @note.body_html
json.set! :body_text, @note.body
json.set! :ticket_id, @note.notable.display_id
json.set! :to_emails, @note.to_emails

json.set! :attachments do
  json.array! @note.attachments do |att|
    json.set! :id, att.id
    json.set! :content_type, att.content_content_type
    json.set! :size, att.content_file_size
    json.set! :name, att.content_file_name
    json.set! :attachment_url, att.attachment_url_for_api
    json.partial! 'shared/utc_date_format', item: att
  end
end

json.set! :user, @user.to_hash
json.partial! 'shared/utc_date_format', item: @note
