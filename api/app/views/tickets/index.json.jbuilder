json.array! @items do |tkt|
  json.cache! tkt do
    json.set! :cc_emails, tkt.cc_email.try(:[], :cc_emails)
    json.set! :fwd_emails, tkt.cc_email.try(:[], :fwd_emails)
    json.set! :reply_cc_emails, tkt.cc_email.try(:[], :reply_cc)

    json.set! :deleted, tkt.deleted.to_s.to_bool if tkt.deleted

    json.(tkt, :description, :description_html, :email_config_id, :group_id, :priority, :requester_id, :responder_id, :source, :status, :subject, :to_email, :to_emails, :product_id)

    json.set! :ticket_id, tkt.display_id
    json.set! :type, tkt.ticket_type

    json.partial! 'shared/boolean_format', boolean_fields: { fr_escalated: tkt.fr_escalated, spam: tkt.spam, urgent: tkt.urgent, is_escalated: tkt.isescalated }
    json.partial! 'shared/utc_date_format', item: tkt, add: { due_by: :due_by, frDueBy: :fr_due_by }
  end

  json.set! :custom_fields, tkt.custom_field
end
