class DeletedCustomers < ActiveRecord::Base
	serialize   :account_info
	validates_uniqueness_of :account_id

	after_create :update_crm

	private

		def update_crm
			Resque.enqueue(CRM::AddToCRM::DeletedCustomer, self.id)
		end 
end
