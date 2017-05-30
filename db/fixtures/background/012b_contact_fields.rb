account = Account.current 

contact_form = account.contact_form
no_of_current_fields = contact_form.contact_fields.count

def self.contact_fields_data
  [
    { :name               => "mobile", 
      :label              => "Mobile Phone", 
      :visible_in_portal  => true, 
      :editable_in_portal => true,
      :field_options      => {"widget_position" => 3} },
      
    { :name               => "twitter_id", 
      :label              => "Twitter", 
      :visible_in_portal  => true, 
      :editable_in_portal => true,
      :field_options      => {"widget_position" => 4} },

    { :name               => "client_manager", 
      :label              => "Can see all tickets from his company"},
      
    { :name               => "address", 
      :label              => "Address" },

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
      :contact_form_id    => contact_form.id,
      :name               => f[:name],
      :column_name        => 'default',
      :label              => f[:label],
      :label_in_portal    => f[:label],
      :deleted            => false,
      :field_type         => :"default_#{f[:name]}",
      :position           => i + no_of_current_fields + 1,
      :required_for_agent => f[:required_for_agent] || false,
      :visible_in_portal  => f[:visible_in_portal]  || false,
      :editable_in_portal => f[:editable_in_portal] || false,
      :editable_in_signup => f[:editable_in_signup] || false,
      :required_in_portal => f[:required_in_portal] || false,
      :field_options      => f[:field_options]
    }
  end
)
contact_form.clear_cache