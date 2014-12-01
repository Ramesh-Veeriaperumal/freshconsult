account = Account.current

ContactForm.seed(:account_id) do |s|
  s.account_id  = account.id
  s.active      = 1
end

def self.contact_fields_data
  [
    { :name               => "name", 
      :label              => "Full Name", 
      :required_for_agent => true, 
      :visible_in_portal  => true, 
      :editable_in_portal => true,
      :editable_in_signup => true,
      :required_in_portal => true },

    { :name               => "job_title", 
      :label              => "Title", 
      :visible_in_portal  => true, 
      :editable_in_portal => true },
      
    { :name               => "email", 
      :label              => "Email",
      :visible_in_portal  => true,
      :editable_in_portal => false,
      :editable_in_signup => true,
      :required_in_portal => false },  # default validations are present in User model(phone || twitter_id || email)

    { :name               => "phone", 
      :label              => "Work Phone", 
      :visible_in_portal  => true,
      :editable_in_portal => true },

    { :name               => "mobile", 
      :label              => "Mobile Phone", 
      :visible_in_portal  => true, 
      :editable_in_portal => true },
      
    { :name               => "twitter_id", 
      :label              => "Twitter", 
      :visible_in_portal  => true, 
      :editable_in_portal => true },
      
    { :name               => "company_name", 
      :label              => "Company", 
      :visible_in_portal  => true },
      
    { :name               => "client_manager", 
      :label              => "Can see all tickets from his company"},
      
    { :name               => "address", 
      :label              => "Address" },
      
    { :name               => "time_zone", 
      :label              => "Time Zone", 
      :visible_in_portal  => true, 
      :editable_in_portal => true },
    
    { :name               => "language", 
      :label              => "Language", 
      :visible_in_portal  => true, 
      :editable_in_portal => true },

    { :name               => "tag_names", 
      :label              => "Tags" },
    
    { :name               => "description", 
      :label              => "Background Information" }
  ]
end

ContactField.seed_many(:account_id, :name, 
  contact_fields_data.each_with_index.map do |f, i|
    {
      :account_id         => account.id,
      :contact_form_id    => account.contact_form.id,
      :name               => f[:name],
      :column_name        => 'default',
      :label              => f[:label],
      :label_in_portal    => f[:label],
      :deleted            => false,
      :field_type         => :"default_#{f[:name]}",
      :position           => i+1,
      :required_for_agent => f[:required_for_agent] || false,
      :visible_in_portal  => f[:visible_in_portal]  || false,
      :editable_in_portal => f[:editable_in_portal] || false,
      :editable_in_signup => f[:editable_in_signup] || false,
      :required_in_portal => f[:required_in_portal] || false
    }
  end
)