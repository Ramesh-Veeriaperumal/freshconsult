json.cache! @group do
  json.(@group, :id, :name, :description, :business_calendar_id, :escalate_to, :ticket_assign_type, :assign_time)
  json.agent_list @group.agent_groups.map { |agents| agents.id.to_s }.join(',')
  json.partial! 'shared/utc_date_format', item: @group
end
