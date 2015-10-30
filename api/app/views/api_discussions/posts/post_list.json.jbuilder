json.array! @posts do |p|
  json.cache! CacheLib.key(p, params) do
    json.extract! p, :id, :topic_id, :forum_id, :user_id, :answer, :published, :spam, :trash
    json.partial! 'shared/utc_date_format', item: p
  end
  
  # Not caching the body as it has a bigger impact for posts having huge body
  json.set! :body, p.body
  json.set! :body_html, p.body_html
end
