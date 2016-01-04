json.array! @items do |group|
  json.cache! CacheLib.key(group, params) do
    json.extract! group, :id, :name, :description, :escalate_to
    json.set! :business_hour_id, group.business_calendar_id
    json.unassigned_for GroupConstants::UNASSIGNED_FOR_MAP.key(group.assign_time)
    json.partial! 'shared/boolean_format', boolean_fields: { auto_ticket_assign: group.ticket_assign_type } if GroupDecorator.round_robin_enabled?
    json.partial! 'shared/utc_date_format', item: group
  end
end
