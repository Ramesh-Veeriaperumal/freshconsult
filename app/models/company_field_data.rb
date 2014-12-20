class CompanyFieldData < ActiveRecord::Base

  set_table_name "company_field_data"

  belongs_to_account

  stores_custom_field_data :parent_id => :company_id, :parent_class => 'Company', 
                              :form_id => :company_form_id, :form_class => 'CompanyForm',
                              :custom_form_cache_method => :company_form_from_current_account
  
  def company_form_from_current_account
    (Account.current || account).company_form
  end                              
end
