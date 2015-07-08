json.(@api_group, :id, :name, :description, :business_calendar_id, :escalate_to)
json.unassigned_for GroupConstants::UNASSIGNED_FOR_MAP.key(@api_group.assign_time)
json.agents Array.wrap params[:api_group][:agents]
json.partial! 'shared/boolean_format', boolean_fields: { auto_ticket_assign: @api_group.ticket_assign_type } if @round_robin_enabled
json.partial! 'shared/utc_date_format', item: @api_group
