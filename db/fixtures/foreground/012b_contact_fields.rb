include ContactFieldsConstants
account = Account.current

ContactForm.seed(:account_id) do |s|
  s.account_id  = account.id
  s.active      = 1
end

FOREGROUND_CONTACT_FIELDS.each do |f|
  contact_field = ContactField.new(
    :label              => f[:label],
    :label_in_portal    => f[:label],
    :deleted            => false,
    :field_type         => :"default_#{f[:name]}",
    :position           => f[:position],
    :required_for_agent => f[:required_for_agent] || false,
    :visible_in_portal  => f[:visible_in_portal]  || false,
    :editable_in_portal => f[:editable_in_portal] || false,
    :editable_in_signup => f[:editable_in_signup] || false,
    :required_in_portal => f[:required_in_portal] || false,
    :field_options      => f[:field_options],
    :position           => f[:position]
  )
  
  # The following are attribute protected.
  contact_field.column_name = 'default'
  contact_field.name = f[:name]
  contact_field.contact_form_id = account.contact_form.id
  contact_field.created_at = Time.zone.now #The important callbacks.
  contact_field.updated_at = Time.zone.now  #The important callbacks.
  contact_field.sneaky_save  #To avoid the callbacks of acts-as-list which is changing the other field positions.
end

account.contact_form.clear_cache