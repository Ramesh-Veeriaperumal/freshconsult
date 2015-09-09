json.array! @items do |contact|
  json.cache! CacheLib.key(contact, params) do
    json.extract! contact, :active, :address, :company_id, :description, :email, :id, :job_title, :language, :mobile, :name, :phone, :time_zone, :twitter_id, :client_manager
    json.partial! 'shared/utc_date_format', item: contact

    json.set! :custom_fields, contact.custom_field
  end
end
