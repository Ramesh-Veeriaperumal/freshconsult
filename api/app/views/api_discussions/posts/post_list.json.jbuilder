json.array! @posts do |p|
  # Not caching the body as it has a bigger impact for posts having huge body
  json.set! :body, p.body
  json.set! :body_html, p.body_html

  json.cache! CacheLib.key(p, params) do
    json.extract! p, :id, :topic_id, :forum_id, :user_id, :answer, :published, :spam, :trash, :created_at, :updated_at
  end
end
