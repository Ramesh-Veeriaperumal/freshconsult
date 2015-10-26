json.array! @items do |sla_policy|
  json.cache! CacheLib.key(sla_policy, params) do
    json.extract! sla_policy, :id, :name, :description, :active, :is_default, :position, :created_at, :updated_at
    json.applicable_to SlaPolicyDecorator.pluralize_conditions(sla_policy.conditions)
  end
end
