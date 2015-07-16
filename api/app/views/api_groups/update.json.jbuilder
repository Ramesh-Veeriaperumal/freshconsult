json.(@item, :id, :name, :description, :business_calendar_id, :escalate_to)
json.unassigned_for GroupConstants::UNASSIGNED_FOR_MAP.key(@item.assign_time)
json.agents @item.agent_groups.map(&:user_id)
json.partial! 'shared/boolean_format', boolean_fields: { auto_ticket_assign: @item.ticket_assign_type } if @round_robin_enabled
json.partial! 'shared/utc_date_format', item: @item
