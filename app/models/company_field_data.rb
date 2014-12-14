class CompanyFieldData < ActiveRecord::Base

  self.table_name = "company_field_data"

  belongs_to_account

  stores_custom_field_data :parent_id => :company_id, :parent_class => 'Company', 
                              :form_id => :company_form_id, :form_class => 'CompanyForm'
  # xss_terminate
  
end
