json.array! @api_groups do |group|
  json.cache! group do
    json.(group, :id, :name, :description, :business_calendar_id, :escalate_to)
    json.unassigned_for ApiConstants::UNASSIGNED_FOR_MAP.key(group.assign_time)
    json.auto_ticket_assign group.ticket_assign_type == 1 ? true : false
    json.partial! 'shared/utc_date_format', item: group
  end
end
