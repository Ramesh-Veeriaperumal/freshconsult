fields = [:created_at, :updated_at]
fields += add if defined?(add)

fields.each do |date_sym|
  json.set! date_sym.to_s, item.send(date_sym).try(:utc) if item.send(date_sym)
end
