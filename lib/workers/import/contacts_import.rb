class Workers::Import::ContactsImport

	extend Resque::AroundPerform

	@queue = "contactImport"

	def self.perform(contact_params)
		Workers::Import::CustomersImportWorker.new(contact_params).perform
	end
end