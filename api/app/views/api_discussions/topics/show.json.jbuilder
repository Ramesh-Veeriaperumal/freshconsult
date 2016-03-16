json.cache! CacheLib.compound_key(@item, ApiConstants::CACHE_VERSION[:v2], params) do
  json.extract! @item, :id, :title, :forum_id, :user_id, :locked, :published, :stamp_type, :replied_by,  :user_votes, :merged_topic_id, :comments_count, :sticky
  json.partial! 'shared/utc_date_format', item: @item, add: { replied_at: :replied_at }
end

json.hits @item.hits
