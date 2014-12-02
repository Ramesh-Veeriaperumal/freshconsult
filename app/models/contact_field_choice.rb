class ContactFieldChoice < ActiveRecord::Base

  belongs_to_account
  
  stores_custom_field_choice  :custom_field_class => 'ContactField', 
                                :custom_field_id => :contact_field_id

end
