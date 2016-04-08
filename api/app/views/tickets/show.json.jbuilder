json.cache! CacheLib.compound_key(@item, ApiConstants::CACHE_VERSION[:v3], params) do # ticket caching
  json.set! :cc_emails, @item.cc_email.try(:[], :cc_emails)
  json.set! :fwd_emails, @item.cc_email.try(:[], :fwd_emails)
  json.set! :reply_cc_emails, @item.cc_email.try(:[], :reply_cc)

  json.extract! @item, :email_config_id, :fr_escalated, :group_id, :priority, :requester_id,  :responder_id, :source, :spam, :status, :subject, :company_id

  json.set! :id, @item.display_id
  json.set! :type, @item.ticket_type
  json.set! :to_emails, @item.schema_less_ticket.try(:to_emails)
  json.set! :product_id, @item.schema_less_ticket.try(:product_id)

  json.set! :deleted, @item.deleted if @item.deleted

  json.partial! 'shared/utc_date_format', item: @item, add: { due_by: :due_by, frDueBy: :fr_due_by }

  json.set! :is_escalated, @item.isescalated
end

json.set! :description, @item.description_html
json.set! :description_text, @item.description

json.partial! 'show_requester' if defined?(@requester)

json.partial! 'show_company' if defined?(@company)

json.extract! @item, :custom_fields

json.set! :tags, @item.tag_names # does not have timestamps, hence no caching

json.partial! 'show_conversations' if @conversations

json.set! :attachments do
  json.array! @item.attachments do |att|
    json.cache! att do # attachment caching
      json.set! :id, att.id
      json.set! :content_type, att.content_content_type
      json.set! :size, att.content_file_size
      json.set! :name, att.content_file_name
      json.partial! 'shared/utc_date_format', item: att
    end
    json.set! :attachment_url, att.attachment_url_for_api
  end
end
