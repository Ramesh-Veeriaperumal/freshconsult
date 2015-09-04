json.extract! @item, :active, :address, :client_manager, :company_id, :deleted, :description, :email, :id, :job_title, :language, :mobile, :name, :phone, :time_zone, :twitter_id
json.partial! 'shared/utc_date_format', item: @item

json.set! :custom_fields, @item.custom_field

json.set! :tags, @item.tags.map(&:name)

if @item.avatar
  json.set! :avatar, @item.avatar do |avatar|
    json.set! :avatar_url, avatar.attachment_url_for_api
    json.set! :content_type, avatar.content_content_type
    json.set! :id, avatar.id
    json.set! :name, avatar.content_file_name
    json.set! :size, avatar.content_file_size
    json.partial! 'shared/utc_date_format', item: avatar
  end
else
  json.set! :avatar, nil
end
