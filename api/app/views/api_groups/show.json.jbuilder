json.cache! CacheLib.key(@item, params) do
  json.extract! @item, :id, :name, :description, :business_calendar_id, :escalate_to
  json.unassigned_for GroupConstants::UNASSIGNED_FOR_MAP.key(@item.assign_time)
  json.partial! 'shared/boolean_format', boolean_fields: { auto_ticket_assign: @item.ticket_assign_type } if GroupDecorator.round_robin_enabled?
  json.partial! 'shared/utc_date_format', item: @item
end

json.agent_ids @item.agent_groups.pluck(:user_id)
