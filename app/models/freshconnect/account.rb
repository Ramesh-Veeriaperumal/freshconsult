class Freshconnect::Account < ActiveRecord::Base
  belongs_to_account
  attr_accessible :account_id, :product_account_id, :enabled, :freshconnect_domain
  self.table_name =  :freshconnect_accounts
  self.primary_key = :id
end
