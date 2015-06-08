json.set! :cc_emails, @ticket.cc_email[:cc_emails]
json.set! :fwd_emails, @ticket.cc_email[:fwd_emails]
json.set! :reply_cc_emails, @ticket.cc_email[:reply_cc]
json.(@ticket, :description, :description_html, :display_id, :deleted, :fr_escalated, :spam, :urgent, :requester_status_name, :email_config_id, :fr_escalated, :group_id, :priority, :requester_id, :responder_id, :source, :status, :subject, :ticket_type, :to_email, :to_emails, :product_id, :attachments)
json.set! :is_escalated, @ticket.isescalated
json.set! :notes, []
json.set! :tags, @ticket.tag_names
json.set! :custom_fields, @ticket.custom_field
json.partial! 'shared/utc_date_format', item: @ticket, add: { due_by: :due_by, frDueBy: :fr_due_by }
