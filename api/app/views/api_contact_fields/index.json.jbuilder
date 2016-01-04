json.array! @items do |contact_field|
  json.cache! CacheLib.compound_key(contact_field, contact_field.choices, params) do
    json.extract! contact_field, :editable_in_signup, :id, :label, :name, :position

    json.set! :type, contact_field.field_type
    json.set! :choices, ContactFieldDecorator.contact_field_choices(contact_field) unless contact_field.choices.blank?
    json.set! :default, contact_field.default_field?
    json.set! :customers_can_edit, contact_field.editable_in_portal
    json.set! :label_for_customers, contact_field.label_in_portal
    json.set! :required_for_customers, contact_field.required_in_portal
    json.set! :displayed_for_customers, contact_field.visible_in_portal
    json.set! :required_for_agents, contact_field.required_for_agent

    json.partial! 'shared/utc_date_format', item: contact_field
  end
end
