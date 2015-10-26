json.extract! @item, :id, :name, :description, :business_calendar_id, :escalate_to, :created_at, :updated_at
json.unassigned_for GroupConstants::UNASSIGNED_FOR_MAP.key(@item.assign_time)
json.agent_ids Array.wrap params[:api_group][:agent_ids]
json.partial! 'shared/boolean_format', boolean_fields: { auto_ticket_assign: @item.ticket_assign_type } if @round_robin_enabled
