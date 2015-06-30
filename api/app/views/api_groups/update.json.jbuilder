json.(@api_group, :id, :name, :description, :business_calendar_id, :escalate_to)
json.unassigned_for GroupConstants::UNASSIGNED_FOR_MAP.key(@api_group.assign_time)
json.auto_ticket_assign @api_group.ticket_assign_type if @round_robin_enabled
json.agents @api_group.agent_groups.map(&:user_id)
json.partial! 'shared/utc_date_format', item: @api_group
