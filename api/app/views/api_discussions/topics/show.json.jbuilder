json.cache! [controller_name, action_name, @item] do
  json.(@item, :id, :title, :forum_id, :user_id, :locked, :published, :stamp_type, :replied_by, :posts_count, :hits, :user_votes, :merged_topic_id)
  json.partial! 'shared/boolean_format', boolean_fields: { sticky: @item.sticky }
  json.partial! 'shared/utc_date_format', item: @item, add: { replied_at: :replied_at }
end
