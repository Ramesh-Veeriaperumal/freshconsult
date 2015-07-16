json.(@item, :id, :name, :description, :position, :description_html, :forum_category_id, :forum_type, :forum_visibility, :topics_count, :posts_count)
json.set! :topics do
  json.array! @topics do |t|
    json.cache! t do
      json.(t, :id, :title, :forum_id, :user_id, :stamp_type, :replied_at, :replied_by, :posts_count, :hits, :user_votes, :merged_topic_id)
      json.partial! 'shared/boolean_format', boolean_fields: { locked: t.locked, published: t.published, sticky: t.sticky }
      json.partial! 'shared/utc_date_format', item: t, add: { replied_at: :replied_at }
    end
  end
end
