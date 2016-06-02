json.extract! @item, :id, :user_id, :from_email, :cc_emails, :bcc_emails

json.set! :body, @item.body_html
json.set! :body_text, @item.body
json.set! :ticket_id, @item.ticket.display_id
json.set! :to_emails, @item.to_emails

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
