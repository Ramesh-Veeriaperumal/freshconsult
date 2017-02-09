class CompanyFieldData < ActiveRecord::Base

  self.table_name = "company_field_data"
  self.primary_key = :id

  belongs_to_account

  stores_custom_field_data :parent_id => :company_id, :parent_class => 'Company', 
                              :form_id => :company_form_id, :form_class => 'CompanyForm',
                              :custom_form_cache_method => :company_form_from_current_account,
                              :touch_parent_on_update => true
                              
  def company_form_from_current_account
    (Account.current || account).company_form
  end                              
end
