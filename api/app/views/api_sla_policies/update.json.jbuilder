json.extract! @item, :id, :name, :description, :active, :is_default, :position
json.sla_target SlaPolicyDecorator.pluralize_sla_target(@item.sla_details)
json.applicable_to SlaPolicyDecorator.pluralize_conditions(@item.conditions)
json.escalation SlaPolicyDecorator.pluralize_escalations(@item.escalations)
json.partial! 'shared/utc_date_format', item: @item
