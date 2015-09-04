json.cache! [controller_name, action_name, @item] do
  json.extract! @item, :id, :name, :description, :business_calendar_id, :escalate_to
  json.unassigned_for GroupConstants::UNASSIGNED_FOR_MAP.key(@item.assign_time)
  json.partial! 'shared/boolean_format', boolean_fields: { auto_ticket_assign: @item.ticket_assign_type } if @round_robin_enabled
  json.partial! 'shared/utc_date_format', item: @item
end
# Should not be inside the cache as group's updated_at will not change on adding/removing agent groups
json.agent_ids @item.agent_groups.pluck(:user_id)
