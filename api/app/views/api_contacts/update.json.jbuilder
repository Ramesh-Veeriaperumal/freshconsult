json.extract! @item, :active, :address, :company_id, :deleted, :description, :email, :id, :job_title, :language, :mobile, :name, :phone, :time_zone, :twitter_id, :custom_fields, :tags
json.set! :other_emails, @item.other_emails if @item.contact_merge_enabled?
json.partial! 'shared/utc_date_format', item: @item

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
