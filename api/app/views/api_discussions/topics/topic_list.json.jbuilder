json.array! @items do |t|
  json.cache! CacheLib.compound_key(t, ApiConstants::CACHE_VERSION[:v2], params) do
    json.extract! t, :id, :title, :forum_id, :user_id, :locked, :published, :stamp_type, :replied_by, :user_votes, :merged_topic_id, :comments_count, :sticky
    json.partial! 'shared/utc_date_format', item: t, add: { replied_at: :replied_at }
  end

  json.hits t.hits
end
