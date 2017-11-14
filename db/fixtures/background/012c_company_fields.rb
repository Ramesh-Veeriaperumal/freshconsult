include CompanyFieldsConstants

account = Account.current

COMPANY_FIELDS =
  [
    { :name               => "description", 
      :label              => "Description",
      :position           => 2 },

    { :name               => "note", 
      :label              => "Notes",
      :position           => 3 },

    { :name               => "domains", 
      :label              => "Domain Names for this company",
      :position           => 4 },

    { :name               => "health_score",
      :label              => "Health score",
      :position           => 5 },

    { :name               => "account_tier",
      :label              => "Account tier",
      :position           => 6 },

    { :name               => "renewal_date",
      :label              => "Renewal date",
      :position           => 7 },

    { :name               => "industry", 
      :label              => "Industry",
      :position           => 8 }
  ]

FIELDS_WITH_CHOICES = ['health_score', 'account_tier', 'industry']

def self.company_fields_data
  COMPANY_FIELDS.each_with_index.map do |f, i|
    {
      :name               => f[:name],
      :column_name        => 'default',
      :label              => f[:label],
      :deleted            => false,
      :field_type         => :"default_#{f[:name]}",
      :position           => f[:position],
      :required_for_agent => f[:required_for_agent] || 0,
      :field_options      => f[:field_options] || {}
    }
  end
end

company_fields_data.each do |field_data|
  field_name = field_data.delete(:name)
  column_name = field_data.delete(:column_name)
  deleted = field_data.delete(:deleted)
  if FIELDS_WITH_CHOICES.include?(field_name)
    field_data[:custom_field_choices_attributes] = TAM_FIELDS_DATA["#{field_name}_data"]
  end
  company_field = CompanyField.new(field_data)

  # The following are attribute protected.
  company_field.column_name = column_name
  company_field.name = field_name
  company_field.deleted = deleted
  company_field.company_form_id = account.company_form.id
  company_field.save
end
account.company_form.clear_cache
