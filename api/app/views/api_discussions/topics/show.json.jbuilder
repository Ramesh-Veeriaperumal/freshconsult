json.cache! CacheLib.key(@item, params) do
  json.extract! @item, :id, :title, :forum_id, :user_id, :locked, :published, :stamp_type, :replied_by, :hits, :user_votes, :merged_topic_id
  json.set! :comments_count, @item.posts_count
  json.partial! 'shared/boolean_format', boolean_fields: { sticky: @item.sticky }
  json.partial! 'shared/utc_date_format', item: @item, add: { replied_at: :replied_at }
end
