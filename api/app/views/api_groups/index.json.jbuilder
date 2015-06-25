json.array! @api_groups do |fc|
  json.cache! fc do
    json.(fc, :id, :name, :description, :business_calendar_id, :escalate_to)
    json.unassigned_for ApiConstants::UNASSIGNED_FOR_MAP.key(fc.assign_time)
    json.auto_ticket_assign fc.ticket_assign_type == 1 ? true : false
    json.partial! 'shared/utc_date_format', item: fc
  end
end
