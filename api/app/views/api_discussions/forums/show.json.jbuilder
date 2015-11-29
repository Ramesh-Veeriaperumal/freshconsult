json.cache! CacheLib.key(@item, params) do
  json.extract! @item, :id, :name, :description, :position, :description_html, :forum_category_id, :forum_type, :forum_visibility, :topics_count, :posts_count
  json.set! :company_ids, @item.customer_forums.pluck(:customer_id) if @item.forum_visibility == 4
end
