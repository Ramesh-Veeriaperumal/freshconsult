json.array! @topics do |t|
  json.cache! CacheLib.key(t, params) do
    json.extract! t, :id, :title, :forum_id, :user_id, :locked, :published, :stamp_type, :replied_by, :posts_count, :hits, :user_votes, :merged_topic_id
    json.partial! 'shared/boolean_format', boolean_fields: { sticky: t.sticky }
    json.partial! 'shared/utc_date_format', item: t, add: { replied_at: :replied_at }
  end
end
