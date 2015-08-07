json.array! @items do |contact_field|
  json.(contact_field, :deleted, :editable_in_portal, :editable_in_signup, :field_options, :field_type, :id, :label, :label_in_portal, :name, :position, :required_for_agent, :required_in_portal, :visible_in_portal)

  json.set! :choices, contact_field.choices

  json.partial! 'shared/utc_date_format', item: contact_field
end
