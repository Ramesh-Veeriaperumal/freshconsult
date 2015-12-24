json.array! @forums do |f|
  json.cache! CacheLib.key(f, params) do
    json.extract! f, :id, :name, :description, :position, :description_html, :forum_category_id, :forum_type, :forum_visibility, :topics_count
    json.set! :comments_count, f.posts_count
  end
end
