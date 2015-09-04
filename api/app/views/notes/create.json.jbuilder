json.extract! @item, :body, :body_html, :id, :incoming, :private, :user_id, :support_email

json.set! :ticket_id, @ticket.display_id
json.set! :notified_to, @item.to_emails

json.set! :attachments do
  json.array! @item.attachments do |att|
    json.set! :id, att.id
    json.set! :content_type, att.content_content_type
    json.set! :size, att.content_file_size
    json.set! :name, att.content_file_name
    json.set! :attachment_url, att.attachment_url_for_api
    json.partial! 'shared/utc_date_format', item: att
  end
end

json.partial! 'shared/utc_date_format', item: @item
