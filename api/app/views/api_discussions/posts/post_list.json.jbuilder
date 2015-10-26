json.array! @posts do |p|
  json.cache! CacheLib.key(p, params) do
    json.extract! p, :id, :body, :body_html, :topic_id, :forum_id, :user_id, :answer, :published, :spam, :trash, :created_at, :updated_at
  end
end
