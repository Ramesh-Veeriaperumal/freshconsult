json.array! @decorated_items do |item|
  json.merge! item.to_hash(true)
end
