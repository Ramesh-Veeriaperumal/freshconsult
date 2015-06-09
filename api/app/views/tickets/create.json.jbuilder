json.set! :cc_emails, @ticket.cc_email[:cc_emails]
json.set! :fwd_emails, @ticket.cc_email[:fwd_emails]
json.set! :reply_cc_emails, @ticket.cc_email[:reply_cc]

json.(@ticket, :description, :description_html, :display_id, :fr_escalated, :spam, :urgent, :requester_status_name, :email_config_id, :group_id, :priority, :requester_id, :responder_id, :source, :status, :subject, :ticket_type, :to_email, :to_emails, :product_id)

json.partial! 'shared/utc_date_format', item: @ticket, add: { due_by: :due_by, frDueBy: :fr_due_by }

json.set! :is_escalated, @ticket.isescalated

json.set! :custom_fields, @ticket.custom_field

json.set! :tags, @ticket.tag_names

json.set! :attachments do
  json.array! @ticket.attachments do |att|
    json.set! :id, att.id
    json.set! :content_type, att.content_content_type
    json.set! :file_size, att.content_file_size
    json.set! :file_name, att.content_file_name
    json.partial! 'shared/utc_date_format', item: att
  end
end

json.set! :notes, []
