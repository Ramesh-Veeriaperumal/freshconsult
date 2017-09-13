account = Account.current

CompanyForm.seed(:account_id) do |s|
  s.account_id  = account.id
  s.active      = 1
end

def self.company_fields_data
  [
    { :name               => "name", 
      :label              => "Company Name",
      :required_for_agent => true,
      :position           => 1 },

    { :name               => "domains", 
      :label              => "Domain Names for this company",
      :position           => 4 }
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
  company_field.column_name = 'default'
  company_field.name = f[:name]
  company_field.company_form_id = account.company_form.id
  company_field.sneaky_save #To avoid the callbacks of acts-as-list which is changing the other field positions.
end

account.company_form.clear_cache