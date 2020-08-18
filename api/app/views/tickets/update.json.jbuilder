json.set! :cc_emails, @item.cc_email.try(:[], :cc_emails)
json.set! :fwd_emails, @item.cc_email.try(:[], :fwd_emails)
json.set! :reply_cc_emails, @item.cc_email.try(:[], :reply_cc)
json.set! :ticket_cc_emails, @item.cc_email.try(:[], :tkt_cc)
json.extract! @item, :spam, :email_config_id, :fr_escalated, :group_id, :priority, :requester_id, :responder_id, :source, :status
json.set! :subject, @item.subject_info
json.extract! @item, :company_id, :custom_fields
json.set! :description, @item.description_info[:description]
json.set! :description_text, @item.description_info[:description_text]
json.set! :id, @item.display_id
json.set! :type, @item.ticket_type
json.set! :to_emails, @item.schema_less_ticket.to_emails
json.set! :product_id, @item.schema_less_ticket.product_id
if Account.current.shared_ownership_enabled?
  json.set! :internal_group_id, @item.internal_group_id
  json.set! :internal_agent_id, @item.internal_agent_id
end
if @item.associated_ticket?
  json.set! :association_type, @item.association_type
  json.set! :associated_tickets_list, @item.associates
end
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

json.set! :is_escalated, @item.isescalated
json.set! :tags, @item.tag_names

sla_dates = { due_by: :due_by, frDueBy: :fr_due_by }
if Account.current.next_response_sla_enabled?
  sla_dates.merge!(nr_due_by: :nr_due_by)
  json.set! :nr_escalated, @item.nr_escalated
end
json.partial! 'shared/utc_date_format', item: @item, add: sla_dates

channel_v2_attributes = @item.channel_v2_attributes
stats_hash = @item.stats
json.merge!(channel_v2_attributes) if channel_v2_attributes
json.set! :stats, stats_hash if stats_hash.present? && channel_v2_attributes.present?
