json.cache! @item do
  json.(@item, :id, :title, :forum_id, :user_id, :stamp_type, :replied_by, :posts_count, :hits, :user_votes, :merged_topic_id)
  json.partial! 'shared/boolean_format', boolean_fields: { locked: @item.locked, published: @item.published, sticky: @item.sticky }
  json.partial! 'shared/utc_date_format', item: @item, add: { replied_at: :replied_at }
end
json.set! :posts do
  json.array! @posts do |p|
    json.cache! p do
      json.(p, :id, :body, :body_html, :topic_id, :forum_id, :user_id)
      json.partial! 'shared/boolean_format', boolean_fields: { answer: p.answer, published: p.published, spam: p.spam, trash: p.trash }
      json.partial! 'shared/utc_date_format', item: p
    end
  end
end
