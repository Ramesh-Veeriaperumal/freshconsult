json.cache! @ticket do # ticket caching
  json.set! :cc_emails, @ticket.cc_email[:cc_emails]
  json.set! :fwd_emails, @ticket.cc_email[:fwd_emails]
  json.set! :reply_cc_emails, @ticket.cc_email[:reply_cc]

  json.(@ticket, :description, :description_html, :email_config_id, :fr_escalated, :group_id, :priority, :requester_id,  :responder_id, :to_emails, :product_id, :source, :spam, :status, :subject, :to_email, :urgent)

  json.set! :ticket_id, @ticket.display_id
  json.set! :type, @ticket.ticket_type

  json.set! :is_escalated, @ticket.isescalated

  json.set! :deleted, @ticket.deleted if @ticket.deleted

  json.partial! 'shared/utc_date_format', item: @ticket, add: { due_by: :due_by, frDueBy: :fr_due_by }
end

json.set! :custom_fields, @ticket.custom_field # revisit caching.

json.set! :tags, @ticket.tag_names # does not have timestamps, hence no caching

json.set! :attachments do
  json.array! @ticket.attachments do |att|
    json.cache! att do # attachment caching
      json.set! :id, att.id
      json.set! :content_type, att.content_content_type
      json.set! :size, att.content_file_size
      json.set! :name, att.content_file_name
      json.set! :attachment_url, att.attachment_url_for_api
      json.partial! 'shared/utc_date_format', item: att
    end
  end
end
