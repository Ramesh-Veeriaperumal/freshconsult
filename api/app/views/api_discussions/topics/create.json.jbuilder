json.(@topic, :id, :title, :forum_id, :user_id, :locked, :sticky, :published, :stamp_type, :replied_at, :replied_by, :posts_count, :hits, :user_votes, :merged_topic_id)
json.partial! 'shared/utc_date_format', item: @topic, add: [:replied_at]
