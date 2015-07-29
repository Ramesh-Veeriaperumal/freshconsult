json.cache! @item do
  json.(@item, :active, :address, :client_manager, :company_id, :description, :email, :fb_profile_id, :helpdesk_agent, :id, :job_title, :language, :mobile, :name, :phone, :time_zone, :twitter_id)
  json.partial! 'shared/utc_date_format', item: @item

  json.set! :custom_fields, @item.custom_field

  json.set! :tags, @item.tags.map { |x| x.name }

  json.set! :deleted, @item.deleted if @item.deleted

  if @item.avatar
    json.set! :avatar_attributes do
      json.set! :avatar_url, @item.avatar.attachment_url_for_api
      json.set! :content_type, @item.avatar.content_content_type
      json.set! :id, @item.avatar.id
      json.set! :file_name, @item.avatar.content_file_name
      json.set! :file_size, @item.avatar.content_file_size
      json.partial! 'shared/utc_date_format', item: @item.avatar
    end
  else
    json.set! :avatar_attributes, nil
  end

end