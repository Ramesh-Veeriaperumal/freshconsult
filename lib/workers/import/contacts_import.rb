class Workers::Import::ContactsImport

	extend Resque::AroundPerform

	@queue = "ContactImport"

	def self.perform(contact_params)
		Workers::Import::CustomersImportWorker.new(contact_params).perform
	end
end