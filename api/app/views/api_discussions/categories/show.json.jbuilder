json.cache! @category do
  json.(@category, :id, :name, :description, :position)
  json.partial! 'shared/utc_date_format', item: @category
end

json.set! :forums do
  json.array! @forums do |f|
    json.(f, :id, :name, :description, :position, :description_html, :forum_category_id, :forum_type, :forum_visibility, :topics_count, :posts_count)
  end
end
