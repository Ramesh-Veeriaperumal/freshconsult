json.extract! @item, :id, :name, :description, :active, :is_default, :position
json.applicable_to SlaPolicyDecorator.pluralize_conditions(@item.conditions)
json.partial! 'shared/utc_date_format', item: @item
