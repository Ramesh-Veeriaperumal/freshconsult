json.array! @items do |contact|
  json.cache! CacheLib.compound_key(contact, contact.custom_field, params) do
    json.extract! contact, :active, :address, :company_id, :description, :email, :id, :job_title, :language, :mobile, :name, :phone, :time_zone, :twitter_id, :client_manager, :created_at, :updated_at

    json.set! :custom_fields, contact.custom_field
  end
end
