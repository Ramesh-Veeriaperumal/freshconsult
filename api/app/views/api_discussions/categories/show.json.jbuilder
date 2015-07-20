json.cache! [controller_name, action_name, @item] do
  json.(@item, :id, :name, :description, :position)
  json.partial! 'shared/utc_date_format', item: @item
end

json.set! :forums do
  json.array! @forums do |f|
    json.(f, :id, :name, :description, :position, :description_html, :forum_category_id, :forum_type, :forum_visibility, :topics_count, :posts_count)
  end
end
