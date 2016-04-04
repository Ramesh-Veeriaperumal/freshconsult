json.array! @items do |group|
  json.cache! CacheLib.key(group, params) do
    json.extract! group, :id, :name, :description, :escalate_to, :unassigned_for, :business_hour_id
    json.set! :auto_ticket_assign, group.auto_ticket_assign if group.round_robin_enabled?
    json.partial! 'shared/utc_date_format', item: group
  end
end
