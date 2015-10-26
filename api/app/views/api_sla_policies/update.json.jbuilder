json.extract! @item, :id, :name, :description, :active, :is_default, :position, :created_at, :updated_at
json.applicable_to SlaPolicyDecorator.pluralize_conditions(@item.conditions)
