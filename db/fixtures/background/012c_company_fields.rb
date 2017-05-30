account = Account.current
company_form = account.company_form
no_of_current_fields = company_form.company_fields.count

def self.company_fields_data
  [
    { :name               => "description", 
      :label              => "Description" },
      
    { :name               => "note", 
      :label              => "Notes" }
  ]
end

CompanyField.seed_many(:account_id, :name, 
  company_fields_data.each_with_index.map do |f, i|
    {
      :account_id         => account.id,
      :company_form_id    => company_form.id,
      :name               => f[:name],
      :column_name        => 'default',
      :label              => f[:label],
      :deleted            => false,
      :field_type         => :"default_#{f[:name]}",
      :position           => i + no_of_current_fields + 1,
      :required_for_agent => f[:required_for_agent] || false
    }
  end
)

company_form.clear_cache