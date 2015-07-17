json.set! :cc_emails, @item.cc_email[:cc_emails]
json.set! :fwd_emails, @item.cc_email[:fwd_emails]
json.set! :reply_cc_emails, @item.cc_email[:reply_cc]

json.(@item, :description, :description_html, :email_config_id, :group_id, :priority, :requester_id, :responder_id, :source, :status, :subject, :to_email)

json.set! :to_emails, @item.schema_less_ticket.to_emails
json.set! :product_id, @item.schema_less_ticket.product_id
json.set! :ticket_id, @item.display_id
json.set! :type, @item.ticket_type

json.partial! 'shared/boolean_format', boolean_fields: { fr_escalated: @item.fr_escalated, spam: @item.spam, urgent: @item.urgent, is_escalated: @item.isescalated }
json.partial! 'shared/utc_date_format', item: @item, add: { due_by: :due_by, frDueBy: :fr_due_by }

json.set! :custom_fields, @item.custom_field

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
