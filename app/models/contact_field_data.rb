class ContactFieldData < ActiveRecord::Base

  
  serialize :text_uc02, Hash
  alias_attribute :history_column, :text_uc02
  
  self.table_name = "contact_field_data"
  self.primary_key = :id

  belongs_to_account

  stores_custom_field_data :parent_id => :user_id, :parent_class => 'User', 
                              :form_id => :contact_form_id, :form_class => 'ContactForm',
                              :custom_form_cache_method => :contact_form_from_current_account
  
  def contact_form_from_current_account
    (Account.current || account).contact_form
  end
  
end
