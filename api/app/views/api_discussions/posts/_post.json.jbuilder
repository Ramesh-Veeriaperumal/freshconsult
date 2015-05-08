json.(p, :id, :body, :body_html, :topic_id, :forum_id, :user_id, :answer, :published, :spam, :trash)
json.partial! 'shared/utc_date_format', item: p

