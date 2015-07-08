json.(@topic, :id, :title, :forum_id, :user_id, :stamp_type, :replied_by, :posts_count, :hits, :user_votes, :merged_topic_id)
json.partial! 'shared/boolean_format', boolean_fields: { locked: @topic.locked, published: @topic.published, sticky: @topic.sticky }
json.partial! 'shared/utc_date_format', item: @topic, add: { replied_at: :replied_at }
