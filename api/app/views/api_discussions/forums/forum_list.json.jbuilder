json.array! @forums do |f|
  json.cache! CacheLib.compound_key(f, ApiConstants::CACHE_VERSION[:v2], params) do
    json.extract! f, :id, :name, :description, :position, :forum_category_id, :forum_type, :forum_visibility, :topics_count
    json.set! :comments_count, f.posts_count
  end
end
