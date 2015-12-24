json.extract! @item, :id, :name, :description, :escalate_to
json.set! :business_hour_id, @item.business_calendar_id
json.unassigned_for GroupConstants::UNASSIGNED_FOR_MAP.key(@item.assign_time)
json.agent_ids @item.agent_groups.map(&:user_id)
json.partial! 'shared/boolean_format', boolean_fields: { auto_ticket_assign: @item.ticket_assign_type } if GroupDecorator.round_robin_enabled?
json.partial! 'shared/utc_date_format', item: @item
