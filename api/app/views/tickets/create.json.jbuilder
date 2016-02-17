json.set! :cc_emails, @item.cc_email[:cc_emails]
json.set! :fwd_emails, @item.cc_email[:fwd_emails]
json.set! :reply_cc_emails, @item.cc_email[:reply_cc]

json.extract! @item, :description, :description_html, :fr_escalated, :spam, :email_config_id, :group_id, :priority, :requester_id, :responder_id, :source, :status, :subject, :company_id, :custom_fields

json.set! :to_emails, @item.schema_less_ticket.to_emails
json.set! :product_id, @item.schema_less_ticket.product_id
json.set! :id, @item.display_id
json.set! :type, @item.ticket_type

json.partial! 'shared/utc_date_format', item: @item, add: { due_by: :due_by, frDueBy: :fr_due_by }

json.set! :is_escalated, @item.isescalated

json.set! :tags, @item.tag_names

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
