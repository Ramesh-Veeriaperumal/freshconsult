json.cache! [controller_name, action_name, @item] do
  json.extract! @item, :active, :address, :client_manager, :company_id, :description, :email, :id, :job_title, :language, :mobile, :name, :phone, :time_zone, :twitter_id
  json.partial! 'shared/utc_date_format', item: @item

  json.set! :custom_fields, @item.custom_field

  json.set! :tags, @item.tags.map(&:name)

  json.set! :deleted, @item.deleted if @item.deleted

  if @item.avatar
    json.set! :avatar do
      json.set! :avatar_url, @item.avatar.attachment_url_for_api
      json.set! :content_type, @item.avatar.content_content_type
      json.set! :id, @item.avatar.id
      json.set! :name, @item.avatar.content_file_name
      json.set! :size, @item.avatar.content_file_size
      json.partial! 'shared/utc_date_format', item: @item.avatar
    end
  else
    json.set! :avatar, nil
  end
end
