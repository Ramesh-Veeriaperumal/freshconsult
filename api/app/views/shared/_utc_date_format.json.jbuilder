fields = { created_at: :created_at, updated_at: :updated_at }
fields.merge!(add) if defined?(add) # if other date fields are present

fields.each_pair do |field, display_field|
  json.set! display_field.to_s, item.send(field).try(:utc) if item.send(field)
end
