# Rails uses attributes_cache to fetch attributes. So even though Time.zone is set to UTC, when
# attributes are fetched from cache, rails does not do the time zone conversion. Hence it is not
# guaranteed that response will have dates in UTC. Hence re-introducing the partials.

json.set! :created_at, item.created_at.try(:utc)
json.set! :updated_at, item.updated_at.try(:utc)

if defined?(add)
  add.each_pair do |field, display_field| # if other date fields are present
    json.set! display_field.to_s, item.send(field).try(:utc) if item.respond_to?(field)
  end
end
