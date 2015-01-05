class CompanyFieldChoice < ActiveRecord::Base

  belongs_to_account
  
  stores_custom_field_choice  :custom_field_class => 'CompanyField', 
                                :custom_field_id => :company_field_id

  validates_length_of :value, :in => 1..255
end