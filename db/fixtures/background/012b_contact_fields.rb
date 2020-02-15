account = Account.current 

def self.twitter_requester_fields_data
  return [] unless Account.current.twitter_requester_fields_enabled?

  [
    { name: 'twitter_profile_status',
      label: 'Twitter Profile Status',
      position: 15 },
    { name: 'twitter_followers_count',
      label: 'Twitter Followers Count',
      position: 16 }
  ]
end

def self.contact_fields_data
  [
    { :name               => "mobile", 
      :label              => "Mobile Phone", 
      :visible_in_portal  => true, 
      :editable_in_portal => true,
      :field_options      => {"widget_position" => 3},
      :position           => 5 },
      
    { :name               => "twitter_id", 
      :label              => "Twitter", 
      :visible_in_portal  => true, 
      :editable_in_portal => true,
      :field_options      => {"widget_position" => 4},
      :position           => 6  },

    { :name               => "address", 
      :label              => "Address",
      :position           => 8 },

    { :name               => "tag_names", 
      :label              => "Tags",
      :position           => 11 },
    
    { :name               => "description",
      label:                 'About',
      :position           => 12  },

    { :name               => "client_manager", 
      :label              => "Can see all tickets from his company",
      :position           => 13 },

    { :name               => "unique_external_id", 
      :label              => "Unique External Id",
      :position           => 14 }
  ] + twitter_requester_fields_data
end

last_contact_field = nil

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
  contact_field.column_name = 'default'
  contact_field.name = f[:name]
  contact_field.contact_form_id = account.contact_form.id
  contact_field.created_at = Time.zone.now #The important callbacks.
  contact_field.updated_at = Time.zone.now  #The important callbacks.
  contact_field.sneaky_save #To avoid the callbacks of acts-as-list which is changing the other field positions.
  last_contact_field = contact_field
end

account.contact_form.clear_cache
last_contact_field.update_version_timestamp
