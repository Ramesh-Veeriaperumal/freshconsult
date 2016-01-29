json.array! @items do |tkt|
  json.cache! CacheLib.compound_key(tkt, tkt.schema_less_ticket, ApiConstants::CACHE_VERSION[:v2], params) do
    json.set! :cc_emails, tkt.cc_email.try(:[], :cc_emails)
    json.set! :fwd_emails, tkt.cc_email.try(:[], :fwd_emails)
    json.set! :reply_cc_emails, tkt.cc_email.try(:[], :reply_cc)

    json.set! :deleted, tkt.deleted if tkt.deleted

    json.extract! tkt, :fr_escalated, :spam, :email_config_id, :group_id, :priority, :requester_id, :responder_id, :source, :status, :subject

    json.set! :to_emails, tkt.schema_less_ticket.try(:to_emails)
    json.set! :product_id, tkt.schema_less_ticket.try(:product_id)
    json.set! :id, tkt.display_id
    json.set! :type, tkt.ticket_type

    json.partial! 'shared/utc_date_format', item: tkt, add: { due_by: :due_by, frDueBy: :fr_due_by }

    json.set! :is_escalated, tkt.isescalated
  end

  # Not caching the body as it has a bigger impact for tickets having huge body
  # Not caching custom field as decimal values are read as big decimal object
  # which in turn causes cache to be regenerated for every request as objects will be different.

  json.extract! tkt, :description, :description_html, :custom_fields
end
