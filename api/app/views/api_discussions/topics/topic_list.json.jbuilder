json.array! @topics do |t|
  json.cache! CacheLib.key(t, params) do
    json.extract! t, :id, :title, :forum_id, :user_id, :locked, :published, :stamp_type, :replied_by, :posts_count, :hits, :user_votes, :merged_topic_id, :created_at, :updated_at, :replied_at
    json.partial! 'shared/boolean_format', boolean_fields: { sticky: t.sticky }
  end
end
