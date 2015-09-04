json.array! @items do |sla_policy|
  json.cache! [controller_name, action_name, sla_policy] do
    json.extract! sla_policy, :id, :name, :description, :active, :is_default, :position
    json.applicable_to SlaPolicyDecorator.pluralize_conditions(sla_policy.conditions)
    json.partial! 'shared/utc_date_format', item: sla_policy
  end
end
