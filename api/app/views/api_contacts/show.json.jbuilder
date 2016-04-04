json.cache! CacheLib.compound_key(@item, ApiConstants::CACHE_VERSION[:v3], params) do
  json.extract! @item, :active, :address, :company_id, :description, :email, :id, :job_title, :language, :mobile, :name, :phone, :time_zone, :twitter_id

  json.set! :other_emails, @item.other_emails if @item.contact_merge_enabled?

  json.partial! 'shared/utc_date_format', item: @item

  json.set! :deleted, @item.deleted if @item.deleted
end
json.set! :custom_fields, @item.custom_fields
json.set! :tags, @item.tags

if @item.avatar
  json.set! :avatar do
    json.cache! @item.avatar do
      json.set! :content_type, @item.avatar.content_content_type
      json.set! :id, @item.avatar.id
      json.set! :name, @item.avatar.content_file_name
      json.set! :size, @item.avatar.content_file_size
      json.partial! 'shared/utc_date_format', item: @item.avatar
    end
    json.set! :avatar_url, @item.avatar.attachment_url_for_api
  end
else
  json.set! :avatar, nil
end
