json.array! @items do |tkt|
  json.cache! [controller_name, action_name, tkt] do
    json.set! :cc_emails, tkt.cc_email.try(:[], :cc_emails)
    json.set! :fwd_emails, tkt.cc_email.try(:[], :fwd_emails)
    json.set! :reply_cc_emails, tkt.cc_email.try(:[], :reply_cc)

    json.set! :deleted, tkt.deleted.to_s.to_bool if tkt.deleted

    json.(tkt, :email_config_id, :group_id, :priority, :requester_id, :responder_id, :source, :status, :subject, :to_email)

    json.set! :to_emails, tkt.schema_less_ticket.try(:to_emails)
    json.set! :product_id, tkt.schema_less_ticket.try(:product_id)
    json.set! :ticket_id, tkt.display_id
    json.set! :type, tkt.ticket_type

    json.partial! 'shared/boolean_format', boolean_fields: { fr_escalated: tkt.fr_escalated, spam: tkt.spam,  is_escalated: tkt.isescalated }
    json.partial! 'shared/utc_date_format', item: tkt, add: { due_by: :due_by, frDueBy: :fr_due_by }
  end

  json.cache! tkt.ticket_body do |tbody| # changing desc does not modify ticket's updated_at
    json.set! :description, tkt.description
    json.set! :description_html, tkt.description_html
  end

  json.set! :custom_fields, tkt.custom_field
end
