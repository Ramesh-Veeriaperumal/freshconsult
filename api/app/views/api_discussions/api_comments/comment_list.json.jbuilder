json.array! @comments do |p|
  json.cache! CacheLib.compound_key(p, ApiConstants::CACHE_VERSION[:v2], params) do
    json.extract! p, :id, :topic_id, :forum_id, :user_id, :answer, :published, :spam, :trash
    json.partial! 'shared/utc_date_format', item: p
  end

  # Not caching the body as it has a bigger impact for posts having huge body
  json.set! :body, p.body_html
  json.set! :body_text, p.body
end
