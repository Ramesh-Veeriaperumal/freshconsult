class UserCompany < ActiveRecord::Base

  self.primary_key = :id

  belongs_to_account
  belongs_to :user
  belongs_to :company

  validates_presence_of :user_id, :company_id, :account_id
end
