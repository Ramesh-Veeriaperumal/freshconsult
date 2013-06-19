class Workers::ClearAccountData
	extend Resque::AroundPerform
	
	@queue = "clear_account_data"
	
	class << self
		include FreshdeskCore::Model
		
		def perform(args)
			account = Account.current
			deleted_customer = DeletedCustomers.find_by_account_id(account.id)

			update_status(deleted_customer, STATUS[:in_progress])

			begin
				perform_destroy(account)
			rescue Exception => error
				# NewRelic::Agent.notice_error(error)				
				puts error
				return update_status(deleted_customer, STATUS[:failed])
			end

			update_status(deleted_customer, STATUS[:deleted])
		end

		private 
			
			def update_status(deleted_customer, status)
				deleted_customer.update_attributes(:status => status) if deleted_customer
			end
	end

end