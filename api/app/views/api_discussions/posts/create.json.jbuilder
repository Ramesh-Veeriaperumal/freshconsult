json.(@item, :id, :body, :body_html, :topic_id, :forum_id, :user_id)
json.partial! 'shared/boolean_format', boolean_fields: { answer: @item.answer, published: @item.published, spam: @item.spam, trash: @item.trash }
json.partial! 'shared/utc_date_format', item: @item
