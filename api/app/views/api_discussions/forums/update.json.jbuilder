json.extract! @item, :id, :name, :description, :position, :forum_category_id, :forum_type, :forum_visibility, :topics_count
json.set! :comments_count, @item.posts_count
json.set! :company_ids, @item.customer_forums.pluck(:customer_id) if @item.forum_visibility == 4
