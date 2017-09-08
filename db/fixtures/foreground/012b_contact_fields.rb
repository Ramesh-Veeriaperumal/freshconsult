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
      :required_in_portal => true,
      :position           => 1 },

    { :name               => "job_title",
      :label              => "Title", 
      :visible_in_portal  => true, 
      :editable_in_portal => true,
      :position           => 2 },
      
    { :name               => "email", 
      :label              => "Email",
      :visible_in_portal  => true,
      :editable_in_portal => false,
      :editable_in_signup => true,
      :required_in_portal => false,
      :field_options      => {"widget_position" => 1},
      :position           => 3 },  # default validations are present in User model(phone || twitter_id || email)

    { :name               => "phone", 
      :label              => "Work Phone", 
      :visible_in_portal  => true,
      :editable_in_portal => true,
      :field_options      => {"widget_position" => 2},
      :position           => 4  },

      
    { :name               => "company_name", 
      :label              => "Company", 
      :visible_in_portal  => true,
      :position           => 7 },

    { :name               => "time_zone", 
      :label              => "Time Zone", 
      :visible_in_portal  => true, 
      :editable_in_portal => true,
      :position           => 9 },
      
          
    { :name               => "language", 
      :label              => "Language", 
      :visible_in_portal  => true, 
      :editable_in_portal => true,
      :position           => 10 }
  ]
end

contact_fields_data.each do |f|
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

  contact_field.sneaky_save  #To avoid the callbacks of acts-as-list which is changing the other field positions.
end

account.contact_form.clear_cache