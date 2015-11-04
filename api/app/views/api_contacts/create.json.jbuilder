json.extract! @item, :active, :address, :company_id, :deleted, :description, :email, :id, :job_title, :language, :mobile, :name, :phone, :time_zone, :twitter_id, :client_manager
json.partial! 'shared/utc_date_format', item: @item

json.set! :custom_fields, CustomFieldDecorator.utc_format(@item.custom_field)

json.set! :tags, @item.tags.map(&:name)

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
