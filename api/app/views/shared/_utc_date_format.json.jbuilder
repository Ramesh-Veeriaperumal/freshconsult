# Rails uses attributes_cache to fetch attributes. So even though Time.zone is set to UTC, when 
# attributes are fetched from cache, rails does not do the time zone conversion. Hence it is not 
# guaranteed that response will have dates in UTC. Hence re-introducing the partials.

fields = { created_at: :created_at, updated_at: :updated_at }
fields.merge!(add) if defined?(add) # if other date fields are present

fields.each_pair do |field, display_field|
  json.set! display_field.to_s, item.send(field).try(:utc) if item.respond_to?(field)
end
