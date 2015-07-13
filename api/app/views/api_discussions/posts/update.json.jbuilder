json.(@post, :id, :body, :body_html, :topic_id, :forum_id, :user_id)
json.partial! 'shared/boolean_format', boolean_fields: { answer: @post.answer, published: @post.published, spam: @post.spam, trash: @post.trash }
json.partial! 'shared/utc_date_format', item: @post
