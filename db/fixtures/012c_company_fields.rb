account = Account.current

CompanyForm.seed(:account_id) do |s|
  s.account_id  = account.id
  s.active      = 1
end

def self.company_fields_data
  [
    { :name               => "name", 
      :label              => "Company Name",
      :required_for_agent => true },

    { :name               => "description", 
      :label              => "Description" },
      
    { :name               => "note", 
      :label              => "Notes" },

    { :name               => "domains", 
      :label              => "Domain Names for this company" }
  ]
end

CompanyField.seed_many(:account_id, :name, 
  company_fields_data.each_with_index.map do |f, i|
    {
      :account_id         => account.id,
      :company_form_id    => account.company_form.id,
      :name               => f[:name],
      :column_name        => 'default',
      :label              => f[:label],
      :deleted            => false,
      :field_type         => :"default_#{f[:name]}",
      :position           => i+1,
      :required_for_agent => f[:required_for_agent] || false
    }
  end
)