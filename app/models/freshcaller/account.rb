class Freshcaller::Account < ActiveRecord::Base
  self.table_name =  :freshcaller_accounts
  self.primary_key = :id
  
  belongs_to_account
end
