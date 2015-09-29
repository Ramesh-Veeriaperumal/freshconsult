json.cache! CacheLib.compound_key(@item, @item.ticket_body, @item.custom_field, params) do # ticket caching
  json.set! :cc_emails, @item.cc_email[:cc_emails]
  json.set! :fwd_emails, @item.cc_email[:fwd_emails]
  json.set! :reply_cc_emails, @item.cc_email[:reply_cc]

  json.extract! @item, :email_config_id, :fr_escalated, :group_id, :priority, :requester_id,  :responder_id, :source, :spam, :status, :subject

  json.set! :ticket_id, @item.display_id
  json.set! :type, @item.ticket_type
  json.set! :to_emails, @item.schema_less_ticket.try(:to_emails)
  json.set! :product_id, @item.schema_less_ticket.try(:product_id)

  json.set! :deleted, @item.deleted if @item.deleted

  json.partial! 'shared/utc_date_format', item: @item, add: { due_by: :due_by, frDueBy: :fr_due_by }

  json.set! :is_escalated, @item.isescalated

  json.set! :description, @item.description
  json.set! :description_html, @item.description_html

  json.set! :custom_fields, @item.custom_field # revisit caching.
end

json.set! :tags, @item.tag_names # does not have timestamps, hence no caching

json.partial! 'show_notes' if @notes

json.set! :attachments do
  json.array! @item.attachments do |att|
    json.cache! CacheLib.key(att, params) do # attachment caching
      json.set! :id, att.id
      json.set! :content_type, att.content_content_type
      json.set! :size, att.content_file_size
      json.set! :name, att.content_file_name
      json.partial! 'shared/utc_date_format', item: att
    end
    json.set! :attachment_url, att.attachment_url_for_api
  end
end
