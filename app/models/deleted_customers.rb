class DeletedCustomers < ActiveRecord::Base
  self.primary_key = :id
	serialize   :account_info
	validates_uniqueness_of :account_id

  def reactivate
    event = SubscriptionEvent.deleted_event(account_id)
    event.delete if event
    Resque.remove_delayed(Workers::ClearAccountData, { :account_id => account_id })
    delete
  end
end
