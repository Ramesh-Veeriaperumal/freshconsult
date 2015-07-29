json.array! @items do |contact|
  json.(contact, :active, :address, :company_id, :description, :email, :fb_profile_id, :helpdesk_agent, :id, :job_title, :language, :mobile, :name, :phone, :time_zone, :twitter_id, :client_manager, :deleted)
  json.partial! 'shared/utc_date_format', item: contact

  json.set! :custom_fields, contact.custom_field
end