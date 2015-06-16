json.array! @tickets do |tkt|
  json.cache! tkt do
    json.set! :cc_emails, tkt.cc_email[:cc_emails]
    json.set! :fwd_emails, tkt.cc_email[:fwd_emails]
    json.set! :reply_cc_emails, tkt.cc_email[:reply_cc]

    json.set! :deleted, tkt.deleted if tkt.deleted

    json.(tkt, :description, :description_html, :fr_escalated, :spam, :urgent, :requester_status_name, :email_config_id, :group_id, :priority, :requester_id, :responder_id, :source, :status, :subject, :to_email, :to_emails, :product_id)

    json.set! :ticket_id, tkt.display_id
    json.set! :type, tkt.ticket_type

    json.partial! 'shared/utc_date_format', item: tkt, add: { due_by: :due_by, frDueBy: :fr_due_by }

    json.set! :is_escalated, tkt.isescalated
  end

  json.set! :custom_fields, tkt.custom_field
end
