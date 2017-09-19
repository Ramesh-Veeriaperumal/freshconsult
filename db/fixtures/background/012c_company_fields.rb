account = Account.current

def self.company_fields_data
  [
    { :name               => "description", 
      :label              => "Description",
      :position           => 2 },
      
    { :name               => "note", 
      :label              => "Notes",
      :position           => 3 }
  ]
end

company_fields_data.each do |f|
  company_field = CompanyField.new(
    :label              => f[:label],
    :deleted            => false,
    :field_type         => :"default_#{f[:name]}",
    :position           => f[:position],
    :required_for_agent => f[:required_for_agent] || false,
  )

  # The following are attribute protected.
  company_field.column_name = 'default'
  company_field.name = f[:name]
  company_field.company_form_id = account.company_form.id
  company_field.created_at = Time.zone.now #The important callbacks.
  company_field.updated_at = Time.zone.now  #The important callbacks.
  company_field.sneaky_save #To avoid the callbacks of acts-as-list which is changing the other field positions.
end

account.company_form.clear_cache