json.extract! @item, :body, :body_html, :id, :user_id, :from_email, :cc_emails, :bcc_emails, :created_at, :updated_at

json.set! :ticket_id, @item.notable.display_id
json.set! :replied_to, @item.to_emails

json.set! :attachments do
  json.array! @item.attachments do |att|
    json.set! :id, att.id
    json.set! :content_type, att.content_content_type
    json.set! :size, att.content_file_size
    json.set! :name, att.content_file_name
    json.set! :attachment_url, att.attachment_url_for_api
    json.extract! att, :created_at, :updated_at
  end
end
