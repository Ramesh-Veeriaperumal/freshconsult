json.extract! @item, :id, :topic_id, :forum_id, :user_id, :answer, :published, :spam, :trash
json.partial! 'shared/utc_date_format', item: @item
json.set! :body, @item.body_html
json.set! :body_text, @item.body
