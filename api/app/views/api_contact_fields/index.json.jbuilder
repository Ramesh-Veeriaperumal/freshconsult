json.array! @items do |contact_field|
  json.(contact_field, :deleted, :editable_in_signup, :field_type, :id, :label, :name, :position, :required_for_agent)

  json.set! :choices, contact_field.api_choices
  json.set! :default, contact_field.default_field?
  json.set! :customers_can_edit, contact_field.editable_in_portal
  json.set! :label_for_customers, contact_field.label_in_portal
  json.set! :required_for_customers, contact_field.required_in_portal
  json.set! :displayed_for_customers, contact_field.visible_in_portal

  json.partial! 'shared/utc_date_format', item: contact_field
end
