json.array! @items do |group|
  json.cache! CacheLib.key(group, params) do
    json.extract! group, :id, :name, :description, :business_calendar_id, :escalate_to
    json.unassigned_for GroupConstants::UNASSIGNED_FOR_MAP.key(group.assign_time)
    json.partial! 'shared/boolean_format', boolean_fields: { auto_ticket_assign: group.ticket_assign_type } if GroupDecorator.round_robin_enabled?
    json.partial! 'shared/utc_date_format', item: group
  end
end
