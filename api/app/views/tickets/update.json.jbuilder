json.set! :cc_emails, @ticket.cc_email[:cc_emails]
json.set! :fwd_emails, @ticket.cc_email[:fwd_emails]
json.set! :reply_cc_emails, @ticket.cc_email[:reply_cc]
json.(@ticket, :description, :description_html, :fr_escalated, :spam, :urgent, :requester_status_name, :email_config_id, :fr_escalated, :group_id, :priority, :requester_id, :responder_id, :source, :status, :subject, :to_email, :to_emails, :product_id, :attachments)
json.set! :ticket_id, @ticket.display_id
json.set! :type, @ticket.ticket_type

json.set! :attachments do
  json.array! @ticket.attachments do |att|
    json.set! :id, att.id
    json.set! :content_type, att.content_content_type
    json.set! :file_size, att.content_file_size
    json.set! :file_name, att.content_file_name
    json.partial! 'shared/utc_date_format', item: att
  end
end

json.set! :is_escalated, @ticket.isescalated
json.set! :notes, []
json.set! :tags, @ticket.tag_names
json.set! :custom_fields, @ticket.custom_field
json.partial! 'shared/utc_date_format', item: @ticket, add: { due_by: :due_by, frDueBy: :fr_due_by }
