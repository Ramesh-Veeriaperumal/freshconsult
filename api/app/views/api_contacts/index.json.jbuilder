json.array! @items do |contact|
  json.cache! CacheLib.key(contact, params) do
    json.extract! contact, :active, :address, :company_id, :description, :email, :id, :job_title, :language, :mobile, :name, :phone, :time_zone, :twitter_id, :client_manager
    json.partial! 'shared/utc_date_format', item: contact
  end

  # Not caching as decimal values are read as big decimal object
  # which in turn causes cache to be regenerated for every request as objects will be different.
  json.set! :custom_fields, CustomFieldDecorator.remove_prepended_text_from_custom_fields(contact.custom_field, 3, -1)
end
