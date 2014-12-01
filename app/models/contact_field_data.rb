class ContactFieldData < ActiveRecord::Base

  set_table_name "contact_field_data"

  belongs_to_account

  stores_custom_field_data :parent_id => :user_id, :parent_class => 'User', 
                              :form_id => :contact_form_id, :form_class => 'ContactForm'
  # xss_terminate
  
end
