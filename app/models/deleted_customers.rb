class DeletedCustomers < ActiveRecord::Base
  serialize   :account_info
  validates_uniqueness_of :account_id
end
