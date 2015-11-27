boolean_fields.each_pair do |field, value|
  value ? (json.set! field, value.to_s.to_bool) : (json.set! field, value)
end
