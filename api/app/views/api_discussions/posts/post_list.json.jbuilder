json.array! @posts do |p|
  json.cache! p do
    json.(p, :id, :body, :body_html, :topic_id, :forum_id, :user_id)
    json.partial! 'shared/boolean_format', boolean_fields: { answer: p.answer, published: p.published, spam: p.spam, trash: p.trash }
    json.partial! 'shared/utc_date_format', item: p
  end
end
