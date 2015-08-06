json.array! @posts do |p|
  json.cache! [controller_name, action_name, p] do
    json.(p, :id, :body, :body_html, :topic_id, :forum_id, :user_id, :answer, :published, :spam, :trash)
    json.partial! 'shared/utc_date_format', item: p
  end
end
