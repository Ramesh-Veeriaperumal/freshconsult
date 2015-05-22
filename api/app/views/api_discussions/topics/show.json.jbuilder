json.cache! @topic do
  json.(@topic, :id, :title, :forum_id, :user_id, :locked, :sticky, :published, :stamp_type, :replied_at, :replied_by, :posts_count, :hits, :user_votes, :merged_topic_id)
  json.partial! 'shared/utc_date_format', item: @topic, add: [:replied_at]
end
json.set! :posts do
  json.array! @posts do |p|
    json.cache! p do
      json.(p, :id, :body, :body_html, :topic_id, :forum_id, :user_id, :answer, :published, :spam, :trash)
      json.partial! 'shared/utc_date_format', item: p
    end
  end
end
