json.array! @items do |item|
  json.merge! item.to_hash(true)
end
