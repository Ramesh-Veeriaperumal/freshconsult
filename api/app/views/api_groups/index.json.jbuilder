json.array! @groups do |fc|
  json.cache! fc do
    json.(fc, :id, :name, :description, :business_calendar_id, :escalate_to, :ticket_assign_type, :assign_time)
    json.agent_list fc.agent_groups.map {|agents| agents.id.to_s}.join(",")
    json.partial! 'shared/utc_date_format', item: fc
  end
end