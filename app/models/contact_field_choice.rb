class ContactFieldChoice < ActiveRecord::Base

  self.primary_key = :id
  belongs_to_account
  
  stores_custom_field_choice  :custom_field_class => 'ContactField', 
                                :custom_field_id => :contact_field_id

  validates_length_of :value, :in => 1..255
end
