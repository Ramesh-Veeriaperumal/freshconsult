json.array! @items do |sla_policy|
  json.cache! [controller_name, action_name, sla_policy] do
    json.(sla_policy, :id, :name, :description, :active, :conditions, :is_default, :position)
    json.partial! 'shared/utc_date_format', item: sla_policy
  end
end
