class ContactFieldData < ActiveRecord::Base

  self.table_name= "contact_field_data"

  belongs_to_account

  stores_custom_field_data :parent_id => :user_id, :parent_class => 'User', 
                              :form_id => :contact_form_id, :form_class => 'ContactForm',
                              :custom_form_cache_method => :contact_form_from_current_account
  
  def contact_form_from_current_account
    (Account.current || account).contact_form
  end
  
end
