class CompanyForm < ActiveRecord::Base

  serialize :form_options
  
  belongs_to_account

end
